--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrXml = import 'LrXml'
local LrHttp = import 'LrHttp'

local wordpress = { }

function dump(table)
  local str = "{"
  for n,v in ipairs(table) do
    str = str .. n .. " = " .. v .. ","
  end

  return str .. "}"
end

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

function request(url, method, params)
  local xml = buildXml(method, params)

  local result, hdrs = LrHttp.post(url .. "xmlrpc.php", xml)

  if result == nil then
    error(hdrs.error.name)
  else
    return parseXml(result)
  end
end

function wordpress.getBlog(self)
  local blogs = request(self.url, "wp.getUsersBlogs", {
    self.username,
    self.password,
  })

  if #blogs == 0 then
    error("No blog found")
  elseif #blogs > 1 then
    error("Multi-blog systems aren't supported")
  end

  return blogs[1]
end

function wordpress.newPost(self, blogid, title, content, categories, tags)
  return request(self.url, "wp.newPost", {
    blogid,
    self.username,
    self.password,
    { type = "struct", value = {
      post_title = title,
      post_content = content,
      post_excerpt = "",
      terms = { type = "struct", value = {
        category = { type = "array", value = categories },
        post_tag = { type = "array", value = tags },
      }}
    }}
  })
end

function wordpress.editPost(self, blogid, postid, title, content, categories, tags)
  return request(self.url, "wp.editPost", {
    blogid,
    self.username,
    self.password,
    postid,
    { type = "struct", value = {
      post_title = title,
      post_content = content,
      post_excerpt = "",
      terms = { type = "struct", value = {
        category = { type = "array", value = categories },
        post_tag = { type = "array", value = tags },
      }}
    }}
  })
end

function wordpress.deletePost(self, blogid, postid)
  return request(self.url, "wp.deletePost", {
    blogid,
    self.username,
    self.password,
    postid
  })
end

function Wordpress(url, username, password)
  return {
    url = url,
    username = username,
    password = password,

    getBlog = wordpress.getBlog,
    getCategories = wordpress.getCategories,
    newPost = wordpress.newPost,
    editPost = wordpress.editPost,
    deletePost = wordpress.deletePost,
  }
end
