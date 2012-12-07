--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
require 'Wordpress'

local bind = LrView.bind
local share = LrView.share

local provider = { }

-- This makes us a publish service
provider.supportsIncrementalPublish = 'only'

-- Hide all the normal export settings
provider.showSections = { }

provider.exportPresetFields = {
  { key = 'username', default = "Your username" },
  { key = 'password', default = "Your password" },
  { key = 'site_url', default = "http://www.myblog.com/" },
  { key = 'wordpress_url', default = "" },
}

function provider.sectionsForBottomOfDialog(f, propertyTable)
  local site_url = f:edit_field {
    width_in_chars = 40,
    tooltip = "The address of the blog",
    value = bind 'site_url',
    validate = function(view, value)
      if string.len(value) < 8 then
        return false, value, "Website must be a valid website address"
      end

      if string.sub(value, 0, 7) ~= "http://" and string.sub(value, 0, 8) ~= "https://" then
        return false, value, "Website must be a valid website address"
      end

      if string.sub(value, -1) ~= "/" then
        value = value .. "/"
      end

      return true, value
    end,
  }

  local wp_url = f:edit_field {
    width_in_chars = 40,
    tooltip = "The address of the wordpress install, if different from the site's address",
    value = bind 'wordpress_url',
    validate = function(view, value)
      if string.len(value) == 0 then
        return true, value
      end

      if string.len(value) < 8 then
        return false, value, "Wordpress address must be a valid website address"
      end

      if string.sub(value, 0, 7) ~= "http://" and string.sub(value, 0, 8) ~= "https://" then
        return false, value, "Wordpress address must be a valid website address"
      end

      if string.sub(value, -1) ~= "/" then
        value = value .. "/"
      end

      return true, value
    end,
  }

  local username = f:edit_field {
    width_in_chars = 20,
    tooltip = "The username you use to log in to your blog",
    value = bind 'username',
    validate = function(view, value)
      return string.len(value) > 0, value, "Username cannot be empty"
    end,
  }

  local password = f:password_field {
    width_in_chars = 20,
    tooltip = "The password you use to log in to your blog",
    value = bind 'password',
    validate = function(view, value)
      return string.len(value) > 0, value, "Password cannot be empty"
    end,
  }

  return {
    {
      title = "Login Details",

      synopsis = bind 'username',

      f:column {
        spacing = f:control_spacing(),

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Website:",
            alignment = "right",
            width = LrView.share "label_width",
          },

          site_url
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Wordpress install:",
            alignment = "right",
            width = LrView.share "label_width",
          },

          wp_url
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Username:",
            alignment = "right",
            width = LrView.share "label_width",
          },

          username
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Password:",
            alignment = "right",
            width = LrView.share "label_width",
          },

          password
        },

        f:row {
          spacing = f:label_spacing(),

          f:push_button {
            title = "Validate",
            action = function(button)
              LrTasks.startAsyncTask(function()
                button.enabled = false
                local url = site_url.value
                if string.len(wp_url.value) > 0 then
                  url = wp_url.value
                end
                local wp = Wordpress(url, username.value, password.value)
                local success, error = LrTasks.pcall(function()
                  wp:getBlog()
                end)
                if success then
                  LrDialogs.message("Successfully connected to blog")
                else
                  LrDialogs.message("Failed to access blog: " .. error)
                end
                button.enabled = true
              end)
            end,
          },
        },
      },
    },
  }
end

provider.showSections = { }

provider.canExportVideo = true
provider.small_icon = 'wordpress.png'
provider.supportsCustomSortOrder = false
provider.disableRenamePublishedCollection = false
provider.disableRenamePublishedCollectionSet = false

-- The setting to use for the publish service name if the user doesn't set one
provider.publish_fallbackNameBinding = 'site_url'

function provider.metadataThatTriggersRepublish(publishSettings)
  return {
    default = false,
    title = true,
    caption = true,
    keywords = true,
  }
end

function provider.canAddCommentsToService(publishSettings)
  return false
end

provider.titleForGoToPublishedCollection = "disable"

function provider.viewForCollectionSettings(f, publishSettings, info)
  return f:column {
    bind_to_object = info.collectionSettings,
    fill_horizontal = 1,

    f:group_box {
      title = "Post metadata",
      fill_horizontal = 1,

      f:row {
        spacing = f:label_spacing(),

        f:static_text {
          title = "Categories:",
          alignment = "right",
          width = LrView.share "label_width",
        },

        f:edit_field {
          fill_horizontal = 1,
          tooltip = "Categories to apply to all posts in this collection",
          value = bind 'categories'
        }
      },

      f:row {
        spacing = f:label_spacing(),

        f:static_text {
          title = "Tags:",
          alignment = "right",
          width = LrView.share "label_width",
        },

        f:edit_field {
          fill_horizontal = 1,
          tooltip = "Tags to apply to all posts in this collection",
          value = bind 'tags'
        }
      }
    }
  }
end

function provider.updateExportSettings(exportSettings)
  -- Minimize rendering
  exportSettings.LR_format = 'ORIGINAL'
end

function split(str)
  local result = {}
  for word in str:gmatch("%a+") do
    table.insert(result, word)
  end
  return result
end

function provider.processRenderedPhotos(functionContext, exportContext)
  local publishSettings = exportContext.propertyTable
  local collectionSettings = exportContext.publishedCollection:getCollectionInfoSummary().collectionSettings

  local categories = split(collectionSettings.categories)
  local tags = split(collectionSettings.tags)

  local wp = Wordpress(publishSettings.wordpress_url, publishSettings.username, publishSettings.password)
  local blog = wp:getBlog()

  local scope = exportContext:configureProgress({ title = "Uploading" })

  for i, rendition in exportContext.exportSession:renditions() do
    rendition:skipRender()

    local photo = rendition.photo

    local flickURL = photo:getPropertyForPlugin("info.regex.lightroom.export.flickr2", "url")
    flickURL = flickURL:sub(0, -2):reverse()
    local pos = flickURL:find("/")
    local flickrID = flickURL:sub(0, pos - 1):reverse()

    local content = "[flickr size=\"large\"]" .. flickrID .. "[/flickr]"
    if rendition.publishedPhotoId == nil then
      local id, link = wp:newPost(blog.blogid, photo:getFormattedMetadata("title"), content, categories, tags)
      rendition:recordPublishedPhotoId(id)
      rendition:recordPublishedPhotoUrl(link)
    else
      local id, link = wp:editPost(blog.blogid, rendition.publishedPhotoId, photo:getFormattedMetadata("title"), content, categories, tags)
      rendition:recordPublishedPhotoId(id)
      rendition:recordPublishedPhotoUrl(link)
    end
  end
end

function provider.deletePhotosFromPublishedCollection(publishSettings, arrayOfPhotoIds, deletedCallback)
  local wp = Wordpress(publishSettings.wordpress_url, publishSettings.username, publishSettings.password)
  local blog = wp:getBlog()

  for i, photoId in ipairs(arrayOfPhotoIds) do
    wp:deletePost(blog.blogid, photoId)
    deletedCallback(photoId)
  end
end

return provider
