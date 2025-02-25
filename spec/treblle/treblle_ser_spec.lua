local treblle_ser = require "kong.plugins.treblle.treblle_ser"

describe("treblle_ser module", function()
  describe("serialize", function()
    it("should produce a payload with required keys", function()
      ngx = {
        ctx = {
          treblle = {
            req_body = '{"key": "value"}',
            res_body = '{"result": "ok"}',
            req_internal_id = "service123",
            req_protocol = "HTTP/1.1"
          }
        },
        status = 200,
        var = { host = "localhost", server_port = "80", request_uri = "/test", scheme = "http" },
        req = { 
          start_time = function() return os.time() end, 
          get_headers = function() return { ["user-agent"] = "test-agent" } end 
        },
        log = function() end
      }
      kong = {
        request = {
          get_method = function() return "GET" end,
          get_headers = function() return { ["user-agent"] = "test-agent" } end,
        }
      }
      local conf = { api_key = "test_key", project_id = "proj", mask_keywords = {} }
      local payload = treblle_ser.serialize(ngx, conf)
      assert.is_not_nil(payload.data)
      assert.are.equal("proj", payload.project_id)
    end)
  end)
end)
