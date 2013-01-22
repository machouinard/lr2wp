--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrTasks = import 'LrTasks'
local LrFunctionContext = import 'LrFunctionContext'
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrBinding = import 'LrBinding'
local LrDate = import 'LrDate'

local prefs = import 'LrPrefs'.prefsForPlugin()

local bind = LrView.bind

local Default = {
  id = "default",
  name = "Default",
  post = {
    title = "{title|fileName}",
    content = "[caption align=\"aligncenter\" width=\"{width}\"]<a href=\"{pageurl}\"><img title=\"{title}\" src=\"{imageurl}\" alt=\"{title}\" width=\"{width}\"></a> {title}[/caption]\n{caption}"
  }
}

function clone(obj)
  local result = {}

  for name, value in pairs(obj) do
    if type(value) == 'table' then
      result[name] = clone(value)
    else
      result[name] = value
    end
  end

  return result
end

function makeUniqueID(templates)
  while true do
    local id = math.random(1000000)
    for i, v in ipairs(templates) do
      if v.id == id then
        id = -1
        break
      end
    end
    if id > 0 then
      return id
    end
  end
end

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

function getVariableValue(variable, photo, info)
  -- Special variables for control characters
  if variable == "{" or variable == "}" or variable == ":" then
    return variable
  end

  local value
  if info[variable] ~= nil then
    value = info[variable]
  else
    local success
    success, value = LrTasks.pcall(function()
      return photo:getFormattedMetadata(variable)
    end)
    if not success then
      success, value = LrTasks.pcall(function()
        return photo:getRawMetadata(variable)
      end)

      if not success then
        error("Unknown variable '" .. variable .. "'")
      end
    end
  end

  if value == nil then
    value = ""
  end

  return value
end

function expandVariable(str, photo, info, currentPos)
  -- Find a variable name that is at least one character long
  local pos, pattern = findFirst(str, { "}", "|", "?" }, currentPos + 1)

  if pos == nil then
    error("Unexpected end of template string, looking for '}' in " .. str:sub(currentPos))
  end

  local varname = str:sub(currentPos, pos - 1)
  local value = getVariableValue(varname, photo, info)
  currentPos = pos + 1

  if pattern == "|" then
    -- Allows the simple expansion {title|filename}

    -- Look for the alternate variable name
    pos, pattern = findFirst(str, { "}" }, currentPos)

    if pos == nil then
      error("Unexpected end of template string, looking for '}' in " .. str:sub(currentPos))
    end

    -- If the current value is non-empty then just return that
    if value ~= "" then
      return value, pos + 1
    end

    -- Otherwise get the new variable and return that
    varname = str:sub(currentPos, pos - 1)
    return getVariableValue(varname, photo, info), pos + 1
  elseif pattern == "?" then
    -- Allows the recursive expansion {title?{title}:{filename}}

    local trueStr, falseStr
    trueStr, currentPos = expandString(str, photo, info, currentPos, ":")
    falseStr, currentPos = expandString(str, photo, info, currentPos, "}")

    if value ~= "" then
      return trueStr, currentPos
    else
      return falseStr, currentPos
    end
  end

  return value, currentPos
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
      error("Unexpected end of template string, looking for '" .. endPattern .. "' in '" .. str:sub(currentPos) .. "'")
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

function PostTemplates.editTemplates(template)
  local originalTemplate = template
  return LrFunctionContext.callWithContext('editTemplates', function(context)
    local templates = PostTemplates.getTemplates()

    local properties = LrBinding.makePropertyTable(context)

    properties.template = { template.id }

    function build_list(templates)
      local values = {}
      for i, t in ipairs(templates) do
        table.insert(values, { title = t.name, value = t.id })
      end
      return values
    end

    function templateSelected(props, key, newValue)
      if newValue == nil then
        properties.name = ""
        properties.title = ""
        properties.content = ""
      else
        for i, t in ipairs(templates) do
          if t.id == newValue[1] then
            template = t
          end
        end

        properties.name = template.name
        properties.title = template.post.title
        properties.content = template.post.content
      end
    end
    properties:addObserver('template', templateSelected)

    function nameChanged(props, key, newValue)
      template.name = newValue
      properties.templates = build_list(templates)
    end
    properties:addObserver('name', nameChanged)

    function postContentChanged(props, key, newValue)
      template.post[key] = newValue
    end
    properties:addObserver('title', postContentChanged)
    properties:addObserver('content', postContentChanged)

    properties.templates = build_list(templates)

    local f = LrView.osFactory()
    local contents = f:row {
      bind_to_object = properties,
      spacing = f:dialog_spacing(),
      fill = 1,

      f:column {
        spacing = f:label_spacing(),
        fill_vertical = 1,

        f:static_text {
          title = "Templates:",
          enabled = false
        },

        f:simple_list {
          fill_vertical = 1,
          width = 200,
          height = 400,
          allows_multiple_selection = false,
          items = bind 'templates',
          value = bind 'template'
        },

        f:row {
          f:push_button {
            fill_horizontal = 1,
            title = "Add",
            action = function()
              local newTemplate = clone(Default)
              newTemplate.id = makeUniqueID(templates)
              newTemplate.name = "New Template"
              table.insert(templates, newTemplate)

              properties.templates = build_list(templates)
              properties.template = { newTemplate.id }
            end
          },

          f:push_button {
            fill_horizontal = 1,
            title = "Remove",
            enabled = bind({
              key = 'template',
              transform = function(value)
                return value[1] ~= "default"
              end
            }),
            action = function()
              for i, v in ipairs(templates) do
                if v.id == template.id then
                  table.remove(templates, i)
                  break
                end
              end

              properties.templates = build_list(templates)
              properties.template = { "default" }
            end
          }
        }
      },

      f:column {
        spacing = f:label_spacing(),
        fill = 1,

        f:static_text {
          title = "Template:",
          enabled = false
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Template Name:",
            width = LrView.share "label_width",
          },

          f:edit_field {
            fill_horizontal = 1,
            value = bind 'name',
            enabled = bind({
              key = 'template',
              transform = function(value)
                return value[1] ~= "default"
              end
            }),
          },
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Post Title:",
            width = LrView.share "label_width",
          },

          f:edit_field {
            fill_horizontal = 1,
            value = bind 'title',
          },
        },

        f:static_text {
          title = "Post Content:",
        },

        f:edit_field {
          fill = 1,
          width = 500,
          wraps = true,
          value = bind 'content',
        }
      }
    }

    local result = LrDialogs.presentModalDialog({
      title = "Template Manager",
      contents = contents,
      resizable = "horizontally",
    })

    if result == "ok" then
      PostTemplates.setTemplates(templates)
      return template
    else
      return originalTemplate
    end
  end)
end

function PostTemplates.applyTemplate(template, photo, info, post)
  for name, str in pairs(template.post) do
    post[name] = expandString(str, photo, info)
  end
end

function PostTemplates.getTemplates()
  if prefs.templates == Nil then
    return clone({
      Default
    })
  else
    return clone(prefs.templates)
  end
end

function PostTemplates.setTemplates(templates)
  prefs.templates = templates
end

function PostTemplates.getTemplate(id)
  local templates = PostTemplates.getTemplates()
  for i, template in ipairs(templates) do
    if template.id == id then
      return template
    end
  end

  if id == "default" then
    error("Bad data store")
  end
  error("Missing template")
end
