local M = {}

---Same as Object.assign() in JavaScript
M.assign = function (tables...)
  if #tables == 0 then
    return nil
  end
  local res = tables[0]
  for i,t in ipairs(tables) do
    if i > 1 then
      for k,v in pairs(t) do
        res[k] = v
      end
    end
  end
  return res
end

return M
