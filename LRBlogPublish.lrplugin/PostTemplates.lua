--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrApplication = import 'LrApplication'

local Default = {
  name = "Default",
  post = {
    title = "{title}",
    content = "[caption align=\"aligncenter\" width=\"{width}\"]<a href=\"{pageurl}\"><img title=\"{title}\" src=\"{imageurl}\" alt=\"{title}\" width=\"{width}\"></a> {title}[/caption]"
  }
}

function findFirst(str, patterns, start)
  local first = nil
  local foundpos = nil

  for i, pattern in ipairs(patterns) do
    local pos = str:find(pattern, start)
    if pos ~= nil and (foundpos == nil or foundpos > pos) then
      first = pattern
      foundpos = pos
    end
  end

  return foundpos, first
end

function expandVariable(str, photo, info, currentPos)
  local pos, pattern = findFirst(str, { "}" }, currentPos)

  if pos == nil then
    error("Unexpected end of string")
  end

  local varname = str:sub(currentPos, pos - 1)
  local value
  if info[varname] ~= nil then
    value = info[varname]
  else
    value = photo:getFormattedMetadata(varname)
    if value == nil then
      value = photo:getRawMetadata(varname)
    end
  end

  if value == nil then
    value = ""
  end

  return value, pos + 1
end

function expandString(str, photo, info, currentPos, endPattern)
  currentPos = currentPos or 1
  endPattern = endPattern or "$"

  local result = ""
  local patterns = { "{" }
  if endPattern then
    table.insert(patterns, endPattern)
  end

  while currentPos <= str:len() do
    local pos, pattern = findFirst(str, patterns, currentPos)

    if pos == nil then
      error("Unexpected end of string")
    end

    -- Found the end of this string sequence
    if pattern == endPattern then
      result = result .. str:sub(currentPos, pos - 1)
      currentPos = pos + 1
      break
    end

    -- Append up to the current variable
    result = result .. str:sub(currentPos, pos - 1)

    -- Expand the variable
    local variable
    variable, currentPos = expandVariable(str, photo, info, pos + 1)
    result = result .. variable
  end

  return result, currentPos
end

PostTemplates = {}

function PostTemplates.applyTemplate(template, photo, info, post)
  for name, str in pairs(template.post) do
    post[name] = expandString(str, photo, info)
  end
end

function PostTemplates.getTemplates()
  local xml = LrApplication.activeCatalog():getPropertyForPlugin(_PLUGIN, "templates")

  if xml == nil then
    return {
      Default
    }
  end
end

function PostTemplates.getTemplate(name)
  local templates = PostTemplates.getTemplates()
  for i, template in ipairs(templates) do
    if template.name == name then
      return template
    end
  end

  if name == "Default" then
    error("Bad data store")
  end
  error("Missing template")
end
