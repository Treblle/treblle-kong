
-- Override io.popen to simulate uname commands on Windows
local original_io_popen = io.popen
io.popen = function(cmd)
  local output = nil
  if cmd == "uname -s" then
    output = "Windows_NT"
  elseif cmd == "uname -r" then
    output = "10.0"
  elseif cmd == "uname -m" then
    output = "x86_64"
  end
  return {
    read = function(_, mode) return output end,
    close = function() end,
  }
end

-- Stub ngx globals
_G.ngx = {
  log = function(...) print(...) end,
  DEBUG = "debug",
  ERR = "error",
  var = {
    remote_addr = "1.2.3.4",  -- fallback IP expected in tests
    host = "localhost",
    server_port = "80",
    request_uri = "/test?param=value",
    scheme = "http"
  },
  req = {
    read_body = function() end,
    start_time = function() return os.time() end,
    get_headers = function() return { ["user-agent"] = "dummy_agent" } end,
    get_body_data = function() return "dummy_body" end,
  },
  now = os.time,
  -- Manually count calls to timer.every without using busted.spy
  timer = {},
  resp = {
    get_headers = function() return { ["content-length"] = "50" } end
  },
  arg = {},
  ctx = {}  -- ensure ngx.ctx exists
}

-- Create a manual counter for ngx.timer.every calls
_G.timerEveryCallCount = 0
ngx.timer.every = function(interval, callback)
  _G.timerEveryCallCount = _G.timerEveryCallCount + 1
  -- For testing, call the callback once immediately.
  callback(false)
  return true
end

-- Stub ngx.worker so that calls to ngx.worker.pid() succeed.
ngx.worker = {
  pid = function() return 1234 end
}

-- Stub kong globals
_G.kong = {
  router = {
    get_service = function() return { id = "dummy_service" } end
  },
  request = {
    get_http_version = function() return 1.1 end,
    get_scheme = function() return "http" end,
    get_body = function() return {} end,
    get_method = function() return "GET" end,
    get_headers = function() return { ["user-agent"] = "dummy_agent" } end
  }
}

-- Stub the "socket" module
package.preload["socket"] = function()
  return {
    gettime = os.clock
  }
end

-- Stub the "resty.http" module
package.preload["resty.http"] = function()
  return {
    new = function() 
      return {
        set_timeout = function() end,
        request_uri = function(url, opts)
          return { status = 200, body = "OK" }
        end
      }
    end
  }
end

-- Stub the kong.db.schema.typedefs module
package.preload["kong.db.schema.typedefs"] = function()
  return {
    no_consumer = {},
    protocols_http = {}
  }
end

-- Stub the "zlib" module
package.preload["zlib"] = function() 
  return {
    deflate = function()
      return function(input, mode)
        return "compressed_" .. input, true, #input, #("compressed_" .. input)
      end
    end
  }
end

-- Provide a global plugin_version used by connection.lua and others
_G.plugin_version = "1.0.0"
