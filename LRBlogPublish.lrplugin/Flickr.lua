--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrHttp = import 'LrHttp'
local LrXml = import 'LrXml'
local LrDialogs = import 'LrDialogs'

local key = "701a8450706c1af2c950454db92444ec"
local service = "http://api.flickr.com/services/rest/?format=rest&api_key=" .. key

function findChild(node, name)
  for i = 1,node:childCount() do
    local subnode = node:childAtIndex(i)
    if subnode:name() == name then
      return subnode
    end
  end

  return nil
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

Flickr = {}

function Flickr.getSizes(self, photoID)
  local url = service .. "&method=flickr.photos.getSizes&photo_id=" .. photoID
  local result, hdrs = LrHttp.get(url)
  if result == nil then
    error(hdrs.error.name)
  else
    local sizes = {}
    local node = LrXml.parseXml(result)
    local sizes = findChild(node, "sizes")
    local elements = getChildElements(sizes)
    for i, element in ipairs(elements) do
      local attrs = element:attributes()
      sizes[attrs.label.value] = {
        height = attrs.height.value,
        width = attrs.width.value,
        src = attrs.source.value
      }
    end
    return sizes
  end
end

function Flickr.getInfo(self, photoID)
  local url = service .. "&method=flickr.photos.getInfo&photo_id=" .. photoID
  local result, hdrs = LrHttp.get(url)
  if result == nil then
    error(hdrs.error.name)
  end

  local node = LrXml.parseXml(result)
  local photoNode = findChild(node, "photo")
  local photo = {}
  photo.photo = photoNode:attributes()
  local elements = getChildElements(photoNode)
  for i, element in ipairs(elements) do
    if element:name() == "tags" then
    elseif element:name() == "notes" then
    elseif element:name() == "location" then
    elseif element:name() == "urls" then
    else
      if element:text() ~= "" then
        photo[element:name()] = element:text()
      else
        photo[element:name()] = element:attributes()
      end
    end
  end

  return photo
end
