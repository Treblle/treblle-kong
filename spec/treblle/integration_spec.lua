local helpers = require "spec.helpers"
local cjson = require "cjson"

describe("Plugin: treblle (integration)", function()
  local proxy_client

  setup(function()
    local bp = helpers.get_db_utils()

    -- Create test route and service
    local service = bp.services:insert({
      name = "test-service",
      url = "http://mockbin.org"
    })

    local route = bp.routes:insert({
      service = { id = service.id },
      hosts = { "test.com" }
    })

    -- Enable treblle plugin
    bp.plugins:insert({
      name = "treblle",
      route = { id = route.id },
      config = {
        api_key = "test-api-key",
        project_id = "test-project-id",
        mask_keywords = {"password", "token"},
        debug = true
      }
    })

    -- Start Kong
    assert(helpers.start_kong({
      database = "postgres",
      nginx_conf = "spec/fixtures/custom_nginx.template",
      plugins = "bundled,treblle"
    }))
  end)

  teardown(function()
    helpers.stop_kong()
  end)

  before_each(function()
    proxy_client = helpers.proxy_client()
  end)

  after_each(function()
    if proxy_client then
      proxy_client:close()
    end
  end)

  describe("request/response tracking", function()
    it("should process a simple GET request", function()
      local res = assert(proxy_client:send({
        method = "GET",
        path = "/request",
        headers = {
          ["Host"] = "test.com"
        }
      }))

      assert.res_status(200, res)
    end)

    it("should handle JSON payloads", function()
      local res = assert(proxy_client:send({
        method = "POST",
        path = "/request",
        headers = {
          ["Host"] = "test.com",
          ["Content-Type"] = "application/json"
        },
        body = {
          name = "test",
          password = "secret"
        }
      }))

      assert.res_status(200, res)
    end)

    it("should respect maximum body size limits", function()
      local large_body = string.rep("a", 200000) -- Create large payload
      local res = assert(proxy_client:send({
        method = "POST",
        path = "/request",
        headers = {
          ["Host"] = "test.com",
          ["Content-Type"] = "application/json"
        },
        body = { data = large_body }
      }))

      assert.res_status(200, res)
    end)
  end)
end)