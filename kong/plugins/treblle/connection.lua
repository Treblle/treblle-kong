local _M = {}

local socket = require "socket"
local http = require "resty.http"
local ngx_log = ngx.log
local keepalive_timeout = 600000
local endpoints = {
    "https://rocknrolla.treblle.com",
    "https://punisher.treblle.com",
    "https://sicario.treblle.com"
}

-- Get a random endpoint from the endpoints table
local function get_random_endpoint()
    -- Seed the random number generator (only needed once)
    math.randomseed(os.time())

    -- Pick a random index from the endpoints table
    local index = math.random(1, #endpoints)

    -- Return the selected endpoint
    return endpoints[index]
end

-- Create a new http client
function _M.get_client(conf)
    -- Create http client
    local create_client_time = socket.gettime() * 1000
    local httpc = http.new()
    local end_client_time = socket.gettime() * 1000
    if conf.debug then
        ngx_log(ngx.DEBUG,
            "[treblle] Create new client took time - " ..
            tostring(end_client_time - create_client_time) .. " for pid - " .. ngx.worker.pid())
    end
    return httpc
end

-- Send a POST request to the Treblle API
function _M.post_request(httpc, conf, url_path, body, isCompressed)
    local headers = {}
    headers["Connection"] = "Keep-Alive"
    headers["Content-Type"] = "application/json"
    headers["x-api-key"] = conf.api_key
    headers["User-Agent"] = "kong-plugin-treblle/" .. plugin_version
    headers["Content-Length"] = #body
    if isCompressed then
        headers["Content-Encoding"] = "deflate"
    end

    -- Set a timeout for the request (in milliseconds)
    httpc:set_timeout(conf.send_timeout)

    local random_endpoint = get_random_endpoint()
    return httpc:request_uri(random_endpoint .. url_path, {
        method = "POST",
        body = body,
        headers = headers,
        keepalive_timeout = keepalive_timeout -- 10min
    })
end

return _M
