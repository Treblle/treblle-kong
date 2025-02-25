local helpers = require "kong.plugins.treblle.helpers"

describe("helpers module", function()
  describe("prepare_request_uri", function()
    it("should return a proper URI when no mask keywords are provided", function()
      ngx = { var = { request_uri = "/test?param=value", scheme = "http", host = "localhost", server_port = "80" } }
      local conf = { mask_keywords = {} }
      local uri = helpers.prepare_request_uri(ngx, conf)
      assert.are.equal("http://localhost:80/test?param=value", uri)
    end)

    it("should mask sensitive data in the URI", function()
      ngx = { var = { request_uri = "/test?password=secret", scheme = "http", host = "localhost", server_port = "80" } }
      local conf = { mask_keywords = {"password"} }
      local uri = helpers.prepare_request_uri(ngx, conf)
      assert.is_true(string.find(uri, "password=*****") ~= nil)
    end)
  end)
end)
