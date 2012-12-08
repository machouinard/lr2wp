--[[----------------------------------------------------------------------------
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this file,
You can obtain one at http://mozilla.org/MPL/2.0/.
------------------------------------------------------------------------------]]

require 'XmlRpc'
local LrTasks = import 'LrTasks'

local wordpress = { }

function isResult(message, result)
  return message:sub(-string.len(result)) == result
end

function wordpress.getBlog(self)
  local blogs = XmlRpc(self.url, "wp.getUsersBlogs", {
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

function indexOf(table, value)
  for i, v in ipairs(table) do
    if v == value then
      return i
    end
  end
  return -1
end

function clone(oldTable)
  local result = {}
  for i, v in ipairs(oldTable) do
    table.insert(result, v)
  end
  return result
end

function wordpress.convertTerms(self, blogid, taxonomy, terms)
  local termIDs = {}

  local remoteTerms = XmlRpc(self.url, "wp.getTerms", {
    blogid,
    self.username,
    self.password,
    taxonomy
  })

  for i, term in ipairs(remoteTerms) do
    local pos = indexOf(terms, term.slug)
    if pos >= 0 then
      table.remove(terms, pos)
      table.insert(termIDs, term.term_id)
    end
  end

  for i, term in ipairs(terms) do
    table.insert(termIDs, XmlRpc(self.url, "wp.newTerm", {
      blogid,
      self.username,
      self.password,
      { type = "struct", value = {
        name = term,
        taxonomy = taxonomy,
        slug = term
      }}
    }))
  end

  return termIDs
end

function wordpress.newPost(self, blogid, post)
  local categories = self:convertTerms(blogid, "category", post.categories)
  local tags = self:convertTerms(blogid, "post_tag", post.tags)

  local id = XmlRpc(self.url, "wp.newPost", {
    blogid,
    self.username,
    self.password,
    { type = "struct", value = {
      post_title = post.title,
      post_content = post.content,
      post_excerpt = "",
      post_status = post.status,
      terms = { type = "struct", value = {
        category = { type = "array", value = categories },
        post_tag = { type = "array", value = tags },
      }}
    }}
  })

  local currentPost = XmlRpc(self.url, "wp.getPost", {
    blogid,
    self.username,
    self.password,
    id,
    { type = "array", value = {
      "link"
    }}
  })

  return id, currentPost.link
end

function wordpress.editPost(self, blogid, postid, post)
  local categories = self:convertTerms(blogid, "category", post.categories)
  local tags = self:convertTerms(blogid, "post_tag", post.tags)

  local success, currentPost = LrTasks.pcall(function()
    return XmlRpc(self.url, "wp.getPost", {
      blogid,
      self.username,
      self.password,
      postid,
      { type = "array", value = {
        "link"
      }}
    })
  end)

  if not success then
    if isResult(currentPost, "Invalid post ID.") then
      return self:newPost(blogid, post)
    else
      error(currentPost)
    end
  end

  XmlRpc(self.url, "wp.editPost", {
    blogid,
    self.username,
    self.password,
    postid,
    { type = "struct", value = {
      post_title = post.title,
      post_content = post.content,
      post_excerpt = "",
      terms = { type = "struct", value = {
        category = { type = "array", value = categories },
        post_tag = { type = "array", value = tags },
      }}
    }}
  })

  return postid, post.link
end

function wordpress.deletePost(self, blogid, postid)
  local success, result = LrTasks.pcall(function()
    return XmlRpc(self.url, "wp.deletePost", {
      blogid,
      self.username,
      self.password,
      postid
    })
  end)

  if not success and not isResult(result, "Invalid post ID.") then
    error(result)
  end
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
    convertTerms = wordpress.convertTerms,
  }
end
