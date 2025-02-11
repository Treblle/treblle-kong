local _M = {}

-- Prepare request URI
-- @param `ngx`  Nginx object
-- @param `conf`     Configuration table, holds http endpoint details
-- @return `url` Request URI
function _M.prepare_request_uri(ngx, conf)
  local request_uri = ngx.var.request_uri
  if next(conf.mask_keywords) ~= nil and request_uri ~= nil then
    for _, value in ipairs(conf.mask_keywords) do
      request_uri = request_uri:gsub(value .. "=[^&]*([^&])", value .. "=*****", 1)
    end
  end
  if request_uri == nil then
    request_uri = "/"
  end
  return ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. request_uri
end

return _M
