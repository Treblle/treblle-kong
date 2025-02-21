local cjson = require "cjson"

local _M = {}

local ngx_log = ngx.log
local ngx_log_ERR = ngx.ERR
local ngx_timer_every = ngx.timer.every
local config_hashes = {}
local has_events = false
local connect = require "kong.plugins.treblle.connection"
local socket = require "socket"
local gc = 0
local health_check = 0
local rec_event = 0
local sent_event = 0
local sent_success = 0
local sent_failure = 0
local timer_wakeup_seconds = 2
entity_rules_hashes = {}
local http = require "resty.http"
local zlib = require 'zlib'

-- Function to log the total memory in use by Lua, measured in kilobytes.
-- This includes all memory allocated for Lua objects, such as tables, strings, and functions.
local function get_memory_usage(stage)
  local total_memory = collectgarbage("count")
  ngx_log(ngx.DEBUG, "[treblle] Memory Usage, " .. stage .. " is - " .. total_memory .. " Kb")
  return total_memory
end

-- Function to send http request
local function send_request(conf, body, isCompressed)
  if conf.debug then
    ngx_log(ngx.DEBUG,
      "[treblle] Body Length - " ..
      tostring(#body) .. " when isCompressed is - " .. tostring(isCompressed) .. " for pid - " .. ngx.worker.pid())
  end

  -- Create http client
  local httpc = connect.get_client(conf)

  local start_req_time = socket.gettime() * 1000
  -- Perform the POST request
  local res, err = connect.post_request(httpc, conf, "", body, isCompressed)

  local end_req_time = socket.gettime() * 1000
  if conf.debug then
    ngx_log(ngx.DEBUG,
      "[treblle] Send HTTP request took time - " ..
      tostring(end_req_time - start_req_time) .. " for pid - " .. ngx.worker.pid())
  end

  if not res then
    ngx_log(ngx_log_ERR, "[treblle] failed to send request: ", err)
  end
  return res, err
end

-- Function to compress payload using zlib deflate
local function compress_data(input_string)
  local compressor = zlib.deflate()
  local compressed_data, eof, bytes_in, bytes_out = compressor(input_string, "finish")
  return compressed_data
end

-- Function to prepare request and send to treblle
local function prepare_request(conf, event, debug)
  -- Encode event
  local start_encode_time = socket.gettime() * 1000
  local body = cjson.encode(event)
  local end_encode_time = socket.gettime() * 1000
  if debug then
    ngx_log(ngx.DEBUG,
      "[treblle] Json Encode took time - " ..
      tostring(end_encode_time - start_encode_time) .. " for pid - " .. ngx.worker.pid())
  end

  local payload = nil
  local isCompressed = conf.enable_compression

  if conf.enable_compression then
    local start_compress_time = socket.gettime() * 1000
    local ok, compressed_body = pcall(compress_data, body)
    local end_compress_time = socket.gettime() * 1000
    if debug then
      ngx_log(ngx.DEBUG,
        "[treblle] zlib deflate compression took time - " ..
        tostring(end_compress_time - start_compress_time) .. " for pid - " .. ngx.worker.pid())
    end

    if not ok then
      if debug then
        ngx_log(ngx_log_ERR, "[treblle] failed to compress body: ", compressed_body)
      end
      payload = body
      isCompressed = false -- if failed to compress, send uncompressed data
    else
      if debug then
        ngx_log(ngx.DEBUG, " [treblle] successfully compressed body")
      end
      payload = compressed_body
    end
  else
    payload = body
  end

  return send_request(conf, payload, isCompressed)
end

-- Send the payload to Treblle API
-- Default retry count is 1 and default retry interval is 5 seconds for any API failure
local function send_payload(event, conf)
  local debug = conf.debug
  local eventsSentSuccessfully = false
  local max_retries = conf.max_retry_count or 1
  local retry_count = 0
  local retry_delay = (conf.retry_interval / 1000) or 5 -- Delay in seconds

  local start_send_time = socket.gettime() * 1000

  while retry_count <= max_retries and not eventsSentSuccessfully do
    local start_post_req_time = socket.gettime() * 1000
    -- Send post request
    local resp, err = prepare_request(conf, event, debug)
    local end_post_req_time = socket.gettime() * 1000
    if conf.debug then
      ngx_log(ngx.DEBUG,
        "[treblle] send request took time - " ..
        tostring(end_post_req_time - start_post_req_time) .. " for pid - " .. ngx.worker.pid())
    end

    if not (resp) or (resp.status ~= 200) then
      retry_count = retry_count + 1
      sent_failure = sent_failure + #event
      eventsSentSuccessfully = false
      local msg = "unavailable"
      if resp then
        msg = tostring(resp.status)
      end
      ngx_log(ngx.DEBUG,
        "[treblle] failed to send " ..
        tostring(#event) ..
        " events with response status - " .. msg .. " in this batch for pid - " .. ngx.worker.pid() ..
        ". Retry count: " .. retry_count)
      if retry_count < max_retries then
        ngx_log(ngx.INFO, "[treblle] Retrying in " .. retry_delay .. " seconds...")
        ngx.sleep(retry_delay) -- Wait for the specified delay before retrying
      end
    else
      eventsSentSuccessfully = true
      sent_success = sent_success + #event
      ngx_log(ngx.DEBUG,
        "[treblle] Events sent successfully. Total number of events sent - " ..
        tostring(#event) .. " in this batch for pid - " .. ngx.worker.pid())
      break
    end
  end

  if conf.debug then
    local end_send_time = socket.gettime() * 1000
    ngx_log(ngx.DEBUG,
      "[treblle] send payload function took time - " ..
      tostring(end_send_time - start_send_time) .. " for pid - " .. ngx.worker.pid())
  end
  if eventsSentSuccessfully ~= true then
    error("failed to send events successfully after " .. max_retries .. " retries")
  end
end


-- Send Events
-- @param `premature`
local function send_event(premature)
  local prv_events = sent_event
  local start_time = socket.gettime() * 1000
  if premature then
    return
  end

  -- Compute memory before the batch is processed
  -- get_memory_usage("Before Processing batch")

  -- Temp hash key for debug
  local temp_hash_key
  repeat
    for key, queue in pairs(queue_hashes) do
      local configuration = config_hashes[key]
      if not configuration then
        ngx_log(ngx.DEBUG, "[treblle] Skipping sending events to Treblle, since no configuration is available yet")
        return
      end
      -- Temp hash key
      temp_hash_key = key
      if #queue > 0 and ((socket.gettime() * 1000 - start_time) <= math.min(configuration.max_callback_time_spent, timer_wakeup_seconds * 500)) then
        if configuration.debug then
          ngx_log(ngx.DEBUG, "[treblle] Sending events to Treblle")
        end
        -- Getting the configuration for this particular key

        local counter = 0
        repeat
          local event = table.remove(queue)
          counter = counter + 1

          local start_pay_time = socket.gettime() * 1000
          if pcall(send_payload, event, configuration) then
            sent_event = sent_event + #event
          else
            if configuration.debug then
              ngx_log(ngx.DEBUG,
                "[treblle] send payload pcall failed while sending the event.. Hence skipping the event" ..
                " for pid - " .. ngx.worker.pid())
            end
          end
          local end_pay_time = socket.gettime() * 1000
          if configuration.debug then
            ngx_log(ngx.DEBUG,
              "[treblle] send payload with event count - " ..
              tostring(#event) ..
              " took time - " .. tostring(end_pay_time - start_pay_time) .. " for pid - " .. ngx.worker.pid())
          end
        until next(queue) == nil

        if #queue > 0 then
          has_events = true
        else
          has_events = false
        end

        if configuration.debug then
          ngx.log(ngx.DEBUG,
            "[treblle] Received Event - " ..
            tostring(rec_event) .. " and Sent Event - " .. tostring(sent_event) .. " for pid - " .. ngx.worker.pid())
        end
      else
        has_events = false
        if #queue <= 0 then
          if configuration.debug then
            ngx_log(ngx.DEBUG, "[treblle] Queue is empty, no events to send " .. " for pid - " .. ngx.worker.pid())
          end
        else
          if configuration.debug then
            ngx_log(ngx.DEBUG, "[treblle] Max callback time exceeds, skip sending events now ")
          end
        end
      end
    end
  until has_events == false

  if not has_events then
    ngx_log(ngx.DEBUG, "[treblle] No events to read from the queue")
  end

  -- Manually garbage collect every 8th cycle
  gc = gc + 1
  if gc == 8 then
    ngx_log(ngx.INFO, "[treblle] Calling GC at - " .. tostring(socket.gettime() * 1000) .. " in pid - " ..
      ngx.worker.pid())
    collectgarbage()
    gc = 0
  end

  -- Periodic health check
  health_check = health_check + 1
  if health_check == 150 then
    if rec_event ~= 0 then
      local event_perc = sent_event / rec_event
      ngx_log(ngx.INFO,
        "[treblle] heartbeat - " ..
        tostring(rec_event) ..
        "/" ..
        tostring(sent_event) ..
        "/" ..
        tostring(sent_success) .. "/" ..
        tostring(sent_failure) .. "/" .. tostring(event_perc) .. " in pid - " .. ngx.worker.pid())
    end
    health_check = 0
  end

  local endtime = socket.gettime() * 1000

  -- Event queue size
  local length = 0
  if queue_hashes[temp_hash_key] ~= nil then
    length = #queue_hashes[temp_hash_key]
  end
  local sent_event_delta = (sent_event - prv_events)
  if sent_event_delta > 0 then
    ngx_log(ngx.DEBUG,
      "[treblle] send events batch took time - " ..
      tostring(endtime - start_time) ..
      " and sent event delta - " ..
      tostring(sent_event_delta) .. " with queue size - " .. tostring(length) .. " for pid - " .. ngx.worker.pid())
  end

  -- Compute memory after the batch is processed
  -- get_memory_usage("After processing batch")
end

-- Log to a Http end point.
-- @param `conf`     Configuration table, holds http endpoint details
-- @param `message`  Message to be logged
-- @param `hash_key` Hash key of the config application Id
local function log(conf, message, hash_key)
  if conf.debug then
    local msg = require("cjson").encode(message)
    ngx_log(ngx.DEBUG, "[treblle] Added Event to the queue. [message] - " .. msg .. " for pid - " .. ngx.worker.pid())
  end
  rec_event = rec_event + 1
  table.insert(queue_hashes[hash_key], message)
end

-- Execute the log function
function _M.execute(conf, message)
  -- Hash key of the config project Id
  local hash_key = conf.project_id

  if config_hashes[hash_key] == nil then
    config_hashes[hash_key] = conf
    queue_hashes[hash_key] = {}
  end

  -- Log event to treblle
  log(conf, message, hash_key)
end

-- Schedule Events
function _M.start_background_thread()
  ngx.log(ngx.DEBUG, "[treblle] Scheduling Events batch job every " .. tostring(timer_wakeup_seconds) .. " seconds")

  local ok, err = ngx_timer_every(timer_wakeup_seconds, send_event)
  if not ok then
    ngx.log(ngx.ERR, "[treblle] Error when scheduling the job: " .. err)
  end
end

return _M
