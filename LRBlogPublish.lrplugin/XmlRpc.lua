--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrXml = import 'LrXml'
local LrHttp = import 'LrHttp'
local LrDate = import 'LrDate'

function addParam(builder, param)
  builder:beginBlock("value")

  local typ = type(param)
  local value = param

  if typ == "table" then
    typ = param.type
    value = param.value
  elseif typ == "number" then
    typ = "int"
  elseif typ ~= "boolean" and typ ~= "string" then
    error("Unknown param type " .. typ)
  end

  if typ == "struct" then
    builder:beginBlock("struct")
    for name,p in pairs(value) do
      builder:beginBlock("member")
      builder:tag("name", name)
      addParam(builder, p)
      builder:endBlock()
    end
    builder:endBlock()
  elseif typ == "array" then
    builder:beginBlock("array")
    builder:beginBlock("data")
    for i,p in ipairs(value) do
      addParam(builder, p)
    end
    builder:endBlock()
    builder:endBlock()
  else
    if typ == "dateTime.iso8601" then
      value = LrDate.timeToUserFormat(value, "%Y%m%dT%H:%M:%S")
      local tz, dst = LrDate.timeZone()
      tz = tz / 60
      if tz < 0 then
        tz = -tz
        value = value .. "-"
      else
        value = value .. "+"
      end
      value = value .. string.format("%02d:%02d", math.floor(tz / 60), tz % 60)
    end

    builder:tag(typ, value)
  end

  builder:endBlock()
end

function buildXml(method, params)
  local builder = LrXml.createXmlBuilder(false)
  builder:beginBlock("methodCall")

  builder:tag("methodName", method)
  builder:beginBlock("params")

  for i,param in ipairs(params) do
    builder:beginBlock("param")
    addParam(builder, param)
    builder:endBlock()
  end

  builder:endBlock()
  builder:endBlock()

  return builder:serialize()
end

function getChildElements(node)
  local elements = {}

  for i = 1,node:childCount() do
    local subnode = node:childAtIndex(i)
    if subnode:type() == "element" then
      table.insert(elements, subnode)
    end
  end

  return elements
end

function findChild(node, name)
  for i = 1,node:childCount() do
    local subnode = node:childAtIndex(i)
    if subnode:name() == name then
      return subnode
    end
  end

  return nil
end

function parseValue(node)
  local value = node
  if value:name() ~= "value" then
    value = findChild(node, "value")
  end
  if value == nil then
    error("Invalid XML-RPC response (missing value)")
  end

  local elements = getChildElements(value)
  if #elements > 1 then
    error("Invalid XML-RPC response (too many elements in value)")
  end

  if elements[1]:name() == "struct" then
    local struct = {}
    local members = getChildElements(elements[1])
    for i,m in ipairs(members) do
      if m:name() ~= "member" then
        error("Invalid XML-RPC response (invalid struct child)")
      end

      local name = findChild(m, "name")
      if name == nil then
        error("Invalid XML-RPC response (missing name in struct)")
      end

      local value = findChild(m, "value")
      struct[name:text()] = parseValue(value)
    end

    return struct
  elseif elements[1]:name() == "array" then
    local data = findChild(elements[1], "data")
    if data == nil then
      error("Invalid XML-RPC response (missing data)")
    end

    local array = {}
    local children = getChildElements(data)
    for i,v in ipairs(children) do
      table.insert(array, parseValue(v))
    end

    return array
  else
    return elements[1]:text()
  end
end

function parseXml(xml)
  local node = LrXml.parseXml(xml)
  if node:name() ~= "methodResponse" then
    error("Invalid XML-RPC response")
  end

  local params = findChild(node, "params")
  if params == nil then
    local fault = findChild(node, "fault")
    if fault ~= nil then
      local result = parseValue(fault)
      error(result.faultString)
    end
    error("Invalid XML-RPC response (missing params)")
  end

  local param = findChild(params, "param")
  if param == nil then
    error("Invalid XML-RPC response (missing param)")
  end

  return parseValue(param)
end

function XmlRpc(url, method, params)
  local xml = buildXml(method, params)

  local result, hdrs = LrHttp.post(url .. "xmlrpc.php", xml)

  if result == nil then
    error(hdrs.error.name)
  else
    return parseXml(result)
  end
end
