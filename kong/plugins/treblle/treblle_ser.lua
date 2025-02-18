local ngx_now = ngx.now
local req_get_method = kong.request.get_method
local req_start_time = ngx.req.start_time
local req_get_headers = ngx.req.get_headers
local res_get_headers = ngx.resp and ngx.resp.get_headers or nil
local cjson_safe = require "cjson.safe"
local _M = {}
local ngx_log = ngx.log
local ngx_log_ERR = ngx.ERR
local client_ip = require "kong.plugins.treblle.client_ip"
local helpers = require "kong.plugins.treblle.helpers"

-- Check if a given body content is a valid JSON
function is_valid_json(body)
  return type(body) == "string"
      and string.sub(body, 1, 1) == "{" or string.sub(body, 1, 1) == "["
end

-- Get the OS information
local os_info = (function()
  local os_info = {
    name = "Unknown",
    release = "Unknown",
    architecture = "Unknown"
  }

  -- Get OS name
  local handle = io.popen("uname -s")
  if handle then
    os_info.name = handle:read("*a"):gsub("\n", "")
    handle:close()
  end

  -- Get OS release
  handle = io.popen("uname -r")
  if handle then
    os_info.release = handle:read("*a"):gsub("\n", "")
    handle:close()
  end

  -- Get OS architecture
  handle = io.popen("uname -m")
  if handle then
    os_info.architecture = handle:read("*a"):gsub("\n", "")
    handle:close()
  end

  return os_info
end)()

-- Get the user agent header
local function getUserAgentHeader(headers)
  if headers["user-agent"] == nil then
    return "N/A"
  end
  return headers["user-agent"]
end

-- Get the load time of the request
local function getLoadTime()
  local current_time = ngx.now()                                         -- Current system time (seconds with milliseconds)
  local load_time_microseconds = (current_time - req_start_time()) * 1e6 -- Convert to microseconds
  return load_time_microseconds
end

-- Get the errors from the response
local function getErrors(response_code, response_body)
  local errors = {}
  if response_code >= 400 and response_code < 600 then
    local message = "API Request failure"

    if type(response_body) == "table" and response_body.message then
      message = response_body.message or message
    end

    local error = {}
    error["message"] = message
    error["source"] = "onError"
    error["type"] = "API Request failure"
    table.insert(errors, error)
  end

  return errors
end

-- Function to mask values in a table
local function mask_sensitive_data(tbl, sensitive_keys)
  if type(tbl) ~= "table" then
    return tbl
  end

  for key, value in pairs(tbl) do
    if type(value) == "table" then
      -- Recursively process nested tables
      mask_sensitive_data(value, sensitive_keys)
    elseif type(value) == "string" then
      -- Mask sensitive values
      for _, sensitive_key in ipairs(sensitive_keys) do
        if key:lower() == sensitive_key:lower() then
          tbl[key] = "****" -- Mask the value
        end
      end
    end
  end

  return tbl
end

-- Get the encoding of the request
local function getEncoding(headers)
  local encoding = nil
  if headers["content-encoding"] ~= nil then
    encoding = headers["content-encoding"]
  end
  return "N/A"
end

-- Get the payload from the request
local function getPayload(body, headers)
  local payload = {}
  local payload_size = 0
  if headers["content-type"] ~= nil and string.find(headers["content-type"], "json") then
    local decoded_body, err = cjson_safe.decode(body)
    if decoded_body then
      payload = decoded_body
      payload_size = string.len(body)
    end
  end
  return payload, payload_size
end

-- Serialize the Treblle request
function _M.serialize(ngx, conf)
  local treblle_ctx = ngx.ctx.treblle or {}
  local request_body_entity
  local response_body_entity
  local req_body_transfer_encoding = nil
  local rsp_body_transfer_encoding = nil
  local request_headers = req_get_headers()
  local response_headers = res_get_headers()
  local request_size = 0
  local response_size = 0
  local req_internal_id = treblle_ctx.req_internal_id

  req_body_transfer_encoding = getEncoding(request_headers)
  request_body_entity, request_size = getPayload(treblle_ctx.req_body, request_headers)
  response_body_entity, response_size = getPayload(treblle_ctx.res_body, response_headers)

  local req_protocol = treblle_ctx.req_protocol
  local timezone = os.date("%Z") or "UTC"

  local payload = {
    internal_id = req_internal_id,
    project_id = conf.project_id,
    version = 0.6,
    sdk = "Kong",
    data = {
      server = {
        timezone = timezone,
        os = {
          name = os_info.name,
          release = os_info.release,
          architecture = os_info.architecture
        },
        software = "Kong",
        signature = "",
        protocol = req_protocol,
        encoding = req_body_transfer_encoding
      },
      request = {
        timestamp = os.date("!%Y-%m-%d %H:%M:%S", req_start_time()),
        ip = client_ip.get_client_ip(request_headers),
        url = helpers.prepare_request_uri(ngx, conf),
        user_agent = getUserAgentHeader(request_headers),
        method = req_get_method(),
        headers = request_headers,
        body = request_body_entity,
      },
      response = {
        headers = response_headers,
        code = ngx.status,
        size = response_size,
        load_time = getLoadTime(),
        body = response_body_entity,
      },
      errors = getErrors(ngx.status, response_body_entity),
    },
  }

  payload = mask_sensitive_data(payload, conf.mask_keywords)
  payload["api_key"] = conf.api_key

  return payload
end

return _M
