--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrView = import 'LrView'

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

          f:edit_field {
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

              return true, value
            end,
          },
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Wordpress install:",
            alignment = "right",
            width = LrView.share "label_width",
          },

          f:edit_field {
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

              return true, value
            end,
          },
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Username:",
            alignment = "right",
            width = LrView.share "label_width",
          },

          f:edit_field {
            width_in_chars = 20,
            tooltip = "The username you use to log in to your blog",
            value = bind 'username',
            validate = function(view, value)
              return string.len(value) > 0, value, "Username cannot be empty"
            end,
          },
        },

        f:row {
          spacing = f:label_spacing(),

          f:static_text {
            title = "Password:",
            alignment = "right",
            width = LrView.share "label_width",
          },

          f:password_field {
            width_in_chars = 20,
            tooltip = "The password you use to log in to your blog",
            value = bind 'password',
            validate = function(view, value)
              return string.len(value) > 0, value, "Password cannot be empty"
            end,
          },
        },
      },
    },
  }
end

function provider.endDialog(propertyTable)
  if string.sub(propertyTable.site_url, -1) ~= "/" then
    propertyTable.site_url = propertyTable.site_url .. "/"
  end

  if string.len(propertyTable.wordpress_url) > 0 then
    if string.sub(propertyTable.wordpress_url, -1) ~= "/" then
      propertyTable.wordpress_url = propertyTable.wordpress_url .. "/"
    end
  end
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

return provider
