local assert = require "luassert"

-- Ensure that globals are set up before loading the module
_G.ngx = {
    req = { 
        read_body = function() end, 
        get_body_data = function() return "dummy_body" end,
        get_headers = function() return { ["content-length"] = "100", ["content-type"] = "application/json" } end,
        start_time = function() return os.time() end,
    },
    ctx = {},
    var = { 
        remote_addr = "127.0.0.1", 
        scheme = "http", 
        host = "localhost", 
        server_port = "80", 
        request_uri = "/test" 
    },
    log = function() end,
    ERR = "ERR",
    DEBUG = "DEBUG",
    timer = {
        every = function(delay, func, ...) 
            return true, nil -- Mock successful timer creation
        end
    }
}

_G.kong = {
    request = {
        get_http_version = function() return 1.1 end,
        get_scheme = function() return "http" end,
        get_body = function() return {} end,
        get_method = function() return "GET" end,
        get_headers = function() return { ["user-agent"] = "test-agent" } end,
    },
    router = { 
        get_service = function() return { id = "service123" } end 
    }
}

-- Mock the socket module
package.loaded["socket"] = {
    gettime = function() return os.time() end
}

-- Clear the module cache so that the handler module picks up our globals
package.loaded["kong.plugins.treblle.handler"] = nil
package.loaded["kong.plugins.treblle.log"] = nil
local handler = require "kong.plugins.treblle.handler"

describe("handler module", function()
    describe("access", function()
        before_each(function()
            _G.ngx.ctx = {}
            _G.queue_hashes = {}
        end)

        it("should populate ngx.ctx.treblle with request details", function()
            local conf = {
                project_id = "proj",
                event_queue_size = 10,
                request_max_body_size_limit = 1000,
                debug = false
            }
            
            handler:access(conf)
            
            assert.is_table(ngx.ctx.treblle)
            assert.equals("service123", ngx.ctx.treblle.req_internal_id)
        end)
    end)

    describe("init_worker", function()
        it("should call init_worker without errors", function()
            local ok, err = pcall(function() handler:init_worker() end)
            assert.is_true(ok)
        end)
    end)
end)