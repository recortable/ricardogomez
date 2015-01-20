
# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end

# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", :locals => {
#  :which_fake_page => "Rendering a fake page with a local variable" }


PAGES_ROOT = File.join(__dir__, 'source/paginas')
rootLength = PAGES_ROOT.length + 1
extLength = '.html.md'.length + 1
Dir[File.join(PAGES_ROOT, '**/*.md')].each do |page|
  path = page[rootLength..-extLength]
  template = "paginas/#{path}.html"
  #puts "proxy #{path} => #{template}"
  proxy path, template, locals: {}, ignore: true
end

data.redirects.each do |k, v|
  puts "REDIRECT ver/#{k} => #{v}"
  redirect "ver/#{k}", to: v
end


helpers do
  def markdown(text)
    Tilt['markdown'].new { text }.render unless text.nil?
  end
end

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'

configure :build do
end

configure :build do
  activate :minify_css
  activate :minify_javascript
  activate :asset_hash
end
