local connection = require "kong.plugins.treblle.connection"

describe("connection module", function()
  describe("get_client", function()
    it("should create and return an http client object", function()
      local conf = { debug = false }
      local client = connection.get_client(conf)
      assert.is_table(client)
    end)
  end)

  describe("post_request", function()
    it("should perform a POST request and return a response", function()
      local conf = { debug = false, api_key = "test_api_key", send_timeout = 1000 }
      local fake_httpc = {
        set_timeout = function(self, timeout) self.timeout = timeout end,
        request_uri = function(self, url, opts)
          return { status = 200, body = "OK" }
        end
      }
      local res = connection.post_request(fake_httpc, conf, "/test", '{"data": "value"}', false)
      assert.are.equal(200, res.status)
    end)
  end)
end)
