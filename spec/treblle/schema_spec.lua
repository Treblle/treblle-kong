local schema = require "kong.plugins.treblle.schema"

describe("schema", function()
  it("should have the name 'treblle'", function()
    assert.are.equal("treblle", schema.name)
  end)

  it("should include required config fields", function()
    local config_fields = schema.fields[3].config.fields
    assert.is_table(config_fields)
    local has_api_key = false
    local has_project_id = false
    for _, field in ipairs(config_fields) do
      if field.api_key then has_api_key = true end
      if field.project_id then has_project_id = true end
    end
    assert.is_true(has_api_key)
    assert.is_true(has_project_id)
  end)
end)
