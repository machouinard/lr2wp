--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

local LrDialogs = import 'LrDialogs'

local provider = { }

-- This makes us a publish service
provider.supportsIncrementalPublish = 'only'

-- Hide all the normal export settings
provider.showSections = { }

function provider.startDialog(propertyTable)
end

function provider.endDialog(propertyTable)
end

function provider.sectionsForTopOfDialog(f, propertyTable)
end

function provider.sectionsForBottomOfDialog(f, propertyTable)
end

provider.showSections = { }

provider.canExportVideo = true
provider.small_icon = 'wordpress.png'
provider.supportsCustomSortOrder = false
provider.disableRenamePublishedCollection = false
provider.disableRenamePublishedCollectionSet = false

-- The setting to use for the publish service name if the user doesn't set one
provider.publish_fallbackNameBinding = 'website'

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
