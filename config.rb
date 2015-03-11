
# don't watch publicar folder
#config[:file_watcher_ignore] << %r{^publicar\/}

activate :directory_indexes

# puts "Building redirects..."
# data.redirects.each do |k, v|
#   redirect "ver/#{k}", to: v
# end

helpers do
  def markdown(text)
    Tilt['markdown'].new { text }.render unless text.nil?
  end
end

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :images_dir, 'images'

configure :build do
  activate :minify_css
  activate :minify_javascript
  activate :asset_hash
end
