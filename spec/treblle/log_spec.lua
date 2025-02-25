local log = require "kong.plugins.treblle.log"

describe("log module", function()
  local config = {
    project_id = "proj",
    api_key = "test_key",
    debug = true,
    send_timeout = 1000,
    retry_interval = 5000,
    max_retry_count = 1,
    event_queue_size = 10,
    request_max_body_size_limit = 1000,
    response_max_body_size_limit = 1000,
    mask_keywords = {}
  }

  before_each(function()
    _G.queue_hashes = {}
    _G.config_hashes = {}
  end)

  describe("execute", function()
    it("should add an event to the queue", function()
      log.execute(config, { event = "test" })
      local queue = _G.queue_hashes[config.project_id]
      assert.is_table(queue)
      assert.is_true(#queue > 0)
    end)
  end)
  

end)
