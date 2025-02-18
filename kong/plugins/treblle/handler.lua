local serializer = require "kong.plugins.treblle.treblle_ser"
local TreblleLogHandler = {
  VERSION  = "1.0.0",
  PRIORITY = 5,
}
local log = require "kong.plugins.treblle.log"
local string_find = string.find
local req_read_body = ngx.req.read_body
local req_get_headers = ngx.req.get_headers
local req_get_body_data = ngx.req.get_body_data
local socket = require "socket"
queue_hashes = {}

-- Function to get the internal id of the service
local function getInternalId()
  local service = kong.router.get_service()

  if service then
    return service.id
  end

  return "unknown"
end

-- Handle the request before it is being proxied to the upstream service
-- Extract request body and req protocol information
function TreblleLogHandler:access(conf)
  local headers = req_get_headers()
  local req_body, res_body = "", ""
  local req_post_args = {}
  local err = nil
  local mimetype = nil
  local content_length = headers["content-length"]

  -- Hash key of the config project Id
  local hash_key = conf.project_id
  if (queue_hashes[hash_key] == nil) or
      (queue_hashes[hash_key] ~= nil and type(queue_hashes[hash_key]) == "table" and #queue_hashes[hash_key] < conf.event_queue_size) then
    -- Read request body
    req_read_body()
    local read_request_body = req_get_body_data()
    if (content_length == nil and read_request_body ~= nil and string.len(read_request_body) <= conf.request_max_body_size_limit) or (content_length ~= nil and tonumber(content_length) <= conf.request_max_body_size_limit) then
      req_body = read_request_body
      local content_type = headers["content-type"]
      if content_type and string_find(content_type:lower(), "application/x-www-form-urlencoded", nil, true) then
        req_post_args, err, mimetype = kong.request.get_body()
      end
    end
  end

  local schema = kong.request.get_scheme()
  local http_version = kong.request.get_http_version()
  local formatted_version = string.format("HTTP/%.1f", http_version)

  if schema == "https" then
    formatted_version = "HTTPS"
  end

  -- keep in memory the bodies for this request
  ngx.ctx.treblle = {
    req_body = req_body,
    res_body = res_body,
    req_post_args = req_post_args,
    req_protocol = formatted_version,
    req_internal_id = getInternalId()
  }
end

-- Handle the response before it is being sent to the client
-- Extract response body
function TreblleLogHandler:body_filter(conf)
  local headers = ngx.resp.get_headers()
  local content_length = headers["content-length"]

  -- Hash key of the config project Id
  local hash_key = conf.project_id
  if (queue_hashes[hash_key] == nil) or
      (queue_hashes[hash_key] ~= nil and type(queue_hashes[hash_key]) == "table" and #queue_hashes[hash_key] < conf.event_queue_size) then
    if (content_length == nil) or (tonumber(content_length) <= conf.response_max_body_size_limit) then
      local chunk = ngx.arg[1]
      local treblle_data = ngx.ctx.treblle or
          { res_body = "" } -- minimize the number of calls to ngx.ctx while fallbacking on default value
      treblle_data.res_body = treblle_data.res_body .. chunk
      ngx.ctx.treblle = treblle_data
    end
  end
end

-- Function to ensure response body size is less than conf.response_max_body_size_limit
function ensure_body_size_under_limit(ngx, conf)
  local treblle_ctx = ngx.ctx.treblle or {}

  if treblle_ctx.res_body ~= nil and (string.len(treblle_ctx.res_body) >= conf.response_max_body_size_limit) then
    treblle_ctx.res_body = nil
  end
end

-- Log the event to the Treblle API
-- Serialize the event and log it to the Treblle API
-- Add the request to the queue
function log_event(ngx, conf)
  local start_log_phase_time = socket.gettime() * 1000
  -- Ensure that the response body size is less than conf.response_max_body_size_limit incase content-lenght header is not set
  ensure_body_size_under_limit(ngx, conf)
  local message = serializer.serialize(ngx, conf)
  log.execute(conf, message)
  local end_log_phase_time = socket.gettime() * 1000
  ngx.log(ngx.DEBUG,
    "[treblle] log phase took time - " ..
    tostring(end_log_phase_time - start_log_phase_time) .. " for pid - " .. ngx.worker.pid())
end

-- Log the request after completing the API request
-- Log the request to the Treblle API
function TreblleLogHandler:log(conf)
  ngx.log(ngx.DEBUG, '[treblle] Log phase called for the new event ' .. " for pid - " .. ngx.worker.pid())

  -- Hash key of the config project Id
  local hash_key = conf.project_id
  if (queue_hashes[hash_key] == nil) or
      (queue_hashes[hash_key] ~= nil and type(queue_hashes[hash_key]) == "table" and #queue_hashes[hash_key] < conf.event_queue_size) then
    if conf.debug then
      if (queue_hashes[hash_key] ~= nil and type(queue_hashes[hash_key]) == "table") then
        ngx.log(ngx.DEBUG,
          '[treblle] logging new event where the current number of events in the queue is ' ..
          tostring(#queue_hashes[hash_key]) .. " for pid - " .. ngx.worker.pid())
      else
        ngx.log(ngx.DEBUG, '[treblle] logging new event when queue hash is nil ' .. " for pid - " .. ngx.worker.pid())
      end
    end
    log_event(ngx, conf)
  else
    if conf.debug then
      ngx.log(ngx.DEBUG, '[treblle] Queue is full, do not log new events ' .. " for pid - " .. ngx.worker.pid())
    end
  end
end

function TreblleLogHandler:header_filter(conf)

end

-- Initialize the Treblle plugin
function TreblleLogHandler:init_worker()
  log.start_background_thread()
end

-- Plugin version
plugin_version = TreblleLogHandler.VERSION

return TreblleLogHandler
