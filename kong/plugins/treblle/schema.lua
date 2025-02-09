local typedefs = require "kong.db.schema.typedefs"

return {
  name = "treblle",
  fields = {
    {
      consumer = typedefs.no_consumer
    },
    {
      protocols = typedefs.protocols_http
    },
    {
      config = {
        type = "record",
        fields = {
          {
            timeout = { default = 1000, type = "number" }
          },
          {
            connect_timeout = { default = 1000, type = "number" }
          },
          {
            max_retry_count = { default = 1, type = "number" }
          },
          {
            retry_interval = { default = 5000, type = "number" }
          },
          {
            send_timeout = { default = 5000, type = "number" }
          },
          {
            keepalive = { default = 5000, type = "number" }
          },
          {
            event_queue_size = { default = 1000000, type = "number" }
          },
          {
            mask_keywords = { default = {}, type = "array", elements = typedefs.header_name }
          },
          {
            debug = { default = false, type = "boolean" }
          },
          {
            max_callback_time_spent = { default = 750, type = "number" }
          },
          {
            request_max_body_size_limit = { default = 100000, type = "number" }
          },
          {
            response_max_body_size_limit = { default = 100000, type = "number" }
          },
          {
            api_key = { required = true, default = nil, type = "string" }
          },
          {
            project_id = { required = true, default = nil, type = "string" }
          },
        },
      },
    },
  },
  entity_checks = {}
}
