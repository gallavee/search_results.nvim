local http_request = require('http.request')
local ts = vim.treesitter
local q =vim.treesitter.query



local search_google = function(url)

  local req=http_request.new_from_uri(url)
  req.headers:append("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
  req.headers:append("Accept-Language", "en-GB,en-US;q=0.9,en;q=0.8")
  req.headers:append("user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15")

  local headers, stream = req:go()
  local body = assert(stream:get_body_as_string())
  if headers:get ":status" ~= "200" then
      error(body)
  end
  return body
end


local get_links_from_google_search_results= function(results_html)
    local parser=vim.treesitter.get_string_parser(results_html,'html')
    local tree=parser:parse()
    local root=tree[1]:root()

    local query = vim.treesitter.parse_query('html',[[
    (element
    (start_tag (tag_name) (attribute (attribute_name) @n  (#eq? @n "href") (quoted_attribute_value) @v) ) 
    (element
      (start_tag (tag_name) @tag1  (#eq? @tag1 "h3"))
      (text) @text
    )
    ) @e2
    ]])
    res={}
    for _,captures,metadata in query:iter_matches(root,results_html) do
      local url=q.get_node_text(captures[2],results_html)
      local title=q.get_node_text(captures[4],results_html)
      table.insert(res,{url=url,title=title})
    end
    return res
end

local get_links_from_query= function(query)
  local url = 'https://www.google.com/search?q='..query:gsub(' ','+')
  return get_links_from_google_search_results(search_google(url))
end

local test1 = function()
  local url = 'https://www.google.com/search?q=how+to+make+get+request+in+lua'
  local results_html = search_google(url)
  filewrite = io.open("tempfile.html", "w")
  filewrite:write(results_html)
  filewrite:close()
  return get_links_from_google_search_results(results_html)
end

local test2 =function()
local fileread = assert(io.open("tempfile.html", "r"))
local results_html= fileread:read("*all")
fileread:close()
local parser=vim.treesitter.get_string_parser(results_html,'html')
local tree=parser:parse()
local root=tree[1]:root()

local query = vim.treesitter.parse_query('html',[[
(element
(start_tag (tag_name) (attribute (attribute_name) @n  (#eq? @n "href") (quoted_attribute_value) @v) ) 
(element
  (start_tag (tag_name) @tag1  (#eq? @tag1 "h3"))
  (text) @text
)
) @e2
]])
local res={}
for _,captures,metadata in query:iter_matches(root,results_html) do
  local url=q.get_node_text(captures[2],results_html)
  local title=q.get_node_text(captures[4],results_html)
  table.insert(res,{url=url,title=title})
end
return res
end

local test3 =function()
    local query = vim.fn.input('Query: ')
    return get_links_from_query(query)
end

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local sorters = require('telescope.sorters')
local previewers = require('telescope.previewers')
local themes = require('telescope.themes')
local actions = require("telescope.actions")
local action_state = require "telescope.actions.state"
local make_entry = require "telescope.make_entry"

local show_results_in_telescope = function(query)
  local results = get_links_from_query(query)
  local titles={}
  for _,v in ipairs(results) do
    -- 
    table.insert( titles,{v.title,v.url})
  end
  local load_w3m_into_buffer=function(url)
    local cmd_string = string.format([[
    tabnew
    read !w3m -dump %s
    0
    ]],url)

    vim.api.nvim_exec(cmd_string,true)

  end
  local attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local url = selection['value']['url']:gsub( '^"(.*)"$', "%1")
        vim.cmd("OpenBrowser "..url)
      end)
      actions.select_tab:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local url = selection['value']['url']
        load_w3m_into_buffer(url)
      end)
      return true
  end
  local default_opts={
    finder=finders.new_table({
     results = results,
     entry_maker = function(entry)
        return {
          value = entry,
          display = entry['title']..' '..entry['url'],
          ordinal = entry['title'],
        }
      end
    }
      ),
    sorter =sorters.get_generic_fuzzy_sorter({}),
    prompt_title = "Search results for  query: "..query,
    attach_mappings = attach_mappings,
    previewer = previewers.new_termopen_previewer {
      get_command = function(entry)
        return {"w3m",entry['value']['url']:gsub('"','')}
      end,
      scroll_fn= function(self,direction)
        if direction < 0 then
          self._send_input(self,'b')
        else
        self._send_input(self,'<Space>')
        end
      end
    },
  }
  local search_results = function(opts)
    opts = opts or {}
    pickers.new(opts, default_opts):find()
  end

  search_results()
end

local telescope_search_results = function()
  local query = vim.fn.input('Query:')
  show_results_in_telescope(query)
  end

  vim.keymap.set('n',"<leader>st", telescope_search_results, {desc = "find on web and show in vim"})


