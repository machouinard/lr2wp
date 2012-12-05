--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

return {
  LrSdkVersion = 4.0,
  LrSdkMinimumVersion = 4.0, -- minimum SDK version required by this plug-in

  LrToolkitIdentifier = "com.fractalbrew.lrblogpublish",

  LrPluginName = LOC "$$$/LRBlogPublish/PluginName=LRBlogPublish",
  LrPluginInfoUrl = "http://www.fractalbrew.com/labs/lrblogpublish",

  LrExportServiceProvider = {
    title = "Blog",
    file = "BlogProvider.lua",
  },

  VERSION = { major=0, minor=1, revision=0, build=0, },
}
