local helpers = require "kong.plugins.treblle.helpers"
local client_ip = require "kong.plugins.treblle.client_ip"
local serializer = require "kong.plugins.treblle.treblle_ser"

describe("Treblle plugin", function()
  local mock_ngx
  local mock_conf

  before_each(function()
    -- Mock NGX context
    mock_ngx = {
      var = {
        request_uri = "/api/test?key=value",
        scheme = "http",
        host = "localhost",
        server_port = "8000",
        remote_addr = "127.0.0.1"
      },
      ctx = {
        treblle = {
          req_body = '{"test": "data"}',
          res_body = '{"result": "success"}',
          req_protocol = "HTTP/1.1",
          req_internal_id = "test-id"
        }
      },
      status = 200,
      req = {
        start_time = function() return 1613463000 end
      }
    }

    -- Mock configuration
    mock_conf = {
      api_key = "test-api-key",
      project_id = "test-project-id",
      mask_keywords = {"password", "token"},
      debug = false
    }
  end)

  describe("helpers", function()
    it("should prepare request URI correctly", function()
      local uri = helpers.prepare_request_uri(mock_ngx, mock_conf)
      assert.are.equal("http://localhost:8000/api/test?key=value", uri)
    end)

    it("should mask sensitive parameters in URI", function()
      mock_ngx.var.request_uri = "/api/test?password=secret&token=12345"
      local uri = helpers.prepare_request_uri(mock_ngx, mock_conf)
      assert.are.equal("http://localhost:8000/api/test?password=*****&token=*****", uri)
    end)
  end)

  describe("client_ip", function()
    it("should get client IP from X-Forwarded-For header", function()
      local headers = {
        ["x-forwarded-for"] = "192.168.1.1, 10.0.0.1"
      }
      local ip = client_ip.get_client_ip(headers)
      assert.are.equal("192.168.1.1", ip)
    end)

    it("should handle IPv6 addresses correctly", function()
      local headers = {
        ["x-forwarded-for"] = "2001:db8::1"
      }
      local ip = client_ip.get_client_ip(headers)
      assert.are.equal("2001:db8::1", ip)
    end)

    it("should fallback to remote_addr when no headers present", function()
      local ip = client_ip.get_client_ip({})
      assert.are.equal("127.0.0.1", ip)
    end)
  end)

  describe("serializer", function()
    it("should serialize request/response data correctly", function()
      local payload = serializer.serialize(mock_ngx, mock_conf)
      
      assert.is_table(payload)
      assert.are.equal(mock_conf.project_id, payload.project_id)
      assert.are.equal(mock_conf.api_key, payload.api_key)
      assert.is_table(payload.data)
      assert.is_table(payload.data.request)
      assert.is_table(payload.data.response)
    end)

    it("should mask sensitive data in payload", function()
      mock_ngx.ctx.treblle.req_body = '{"password":"secret","api_token":"12345","name":"test"}'
      
      local payload = serializer.serialize(mock_ngx, mock_conf)
      local decoded_body = require("cjson").decode(payload.data.request.body)
      
      assert.are.equal("****", decoded_body.password)
      assert.are.equal("test", decoded_body.name)
    end)
  end)
end)