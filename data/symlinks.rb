SOURCE_ROOT = File.join(__dir__, '../source')
PAGES_ROOT = File.join(__dir__, '../publicar/paginas')

def remove_symlinks
  puts "REMOVE SYMLINKS FROM: #{SOURCE_ROOT}"
  Dir[File.join(SOURCE_ROOT, '/*')].each do |path|
    if File.symlink?(path)
      puts "Removing symlink: #{path}"
      File.delete(path)
    end
  end
end


def create_symlinks
  puts "CREATE SYMLINKS #{PAGES_ROOT}"
  Dir.chdir(SOURCE_ROOT)
  File.symlink('../publicar/imagenes', 'imagenes')
  base = PAGES_ROOT.length + 1
  Dir[File.join(PAGES_ROOT, '/*')].each do |path|
    filename = path[base..-1]
    puts "Symlink: #{filename}"
    File.symlink("../publicar/paginas/#{filename}", filename)
  end
end

remove_symlinks
create_symlinks

#   PAGES_ROOT = File.join(__dir__, 'source/paginas')
#   rootLength = PAGES_ROOT.length + 1
#   extLength = '.html.md'.length + 1
#   Dir[File.join(PAGES_ROOT, '**/*.md')].each do |page|
#     path = page[rootLength..-extLength]
#     template = "paginas/#{path}.html"
#     #puts "proxy #{path} => #{template}"
#     proxy path, template, locals: {}, ignore: true
#   end
