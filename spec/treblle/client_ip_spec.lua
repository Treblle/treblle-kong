local client_ip = require "kong.plugins.treblle.client_ip"

describe("client_ip module", function()
  describe("get_client_ip", function()
    it("should return the x-client-ip header if present", function()
      local headers = { ["x-client-ip"] = "10.0.0.1" }
      assert.are.equal("10.0.0.1", client_ip.get_client_ip(headers))
    end)
    it("should fall back to ngx.var.remote_addr when no headers are provided", function()
      local headers = {}
      ngx = { var = { remote_addr = "1.2.3.4" } }
      assert.are.equal("1.2.3.4", client_ip.get_client_ip(headers))
    end)
  end)
end)
