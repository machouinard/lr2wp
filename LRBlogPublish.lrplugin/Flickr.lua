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

Flickr = {}

function Flickr.getInfo(self, photoID)
  local url = service .. "&method=flickr.photos.getInfo&photo_id=" .. photoID
  local result, hdrs = LrHttp.get(url)
  if result == nil then
    error(hdrs.error.name)
  else
    local node = LrXml.parseXml(result)
    local photo = findChild(node, "photo")
    return photo:attributes()
  end
end
