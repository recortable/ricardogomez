require 'fileutils'
require 'csv'
require 'yaml'
require 'reverse_markdown'
require_relative 'RedCloth-3.0.4/init'

def blank?(string)
  string.nil? || string.empty?
end

def path(path)
  File.join(__dir__, path)
end

def mkdir(path)
  Dir.mkdir(path) unless File.exist?(path)
end

def write(file, content, meta = nil)
  File.open(file, 'w') do |file|
    if meta
      file.write("---\n")
      meta.each do |key, value|
        val = value ? value.gsub(/[\n]+/, '') : ''
        file.write("#{key}: \"#{val}\"\n")
      end
      file.write("---\n")
    end
    file.write(content)
  end
end


SECTIONS = ['inicio', 'websamigas', 'conferencias', 'paraleer', 'mislibros', 'premios', 'biografia',
  'encuentros', 'matematicas', 'contacto', 'elsahara', 'otras']
def create_sections(dest)
  SECTIONS.each {|s| mkdir(File.join(dest, s)) }
end


def parameterize(string)
  string.downcase.gsub(' ','_').gsub('-', '_')
end

TILDES = {'a' => 'à', 'e' => 'é', 'i' => 'í', 'o' => 'ó', 'u' => 'ú'}
def clean_path(string)
  string = string.downcase.gsub('_', '-')
  TILDES.each {|k, v| string.gsub!(v, k) }
  string
end

class Repo
  attr_reader :name, :all, :keys, :byId

  def initialize(name, keys)
    @name = name
    @keys = keys
    @all = []
    @byId = {}
  end

  def insert(row)
    data = Hash[keys.zip(row)]
    all << data
    byId[data["id"]] = data
  end

  def self.load(name, file)
    repo = nil
    CSV.foreach(file) do |row|
      if repo.nil?
        repo = Repo.new(name, row)
      else
        repo.insert(row)
      end
    end
    repo
  end
end



# id,name,title,section,head,content,end,extra,params,position,created_on,updated_on
class Pages
  attr_reader :pages

  def initialize
    @pages = Repo.load('page', path('pages.csv'))
    pages.all.each do |page|
      page['path'] = build_path(page)
    end
  end

  def export(images, output)
    mkdir(output)
    create_sections(output)

    replaces = {}
    images.all.each {|i| replaces[i['source_path']] = i['dest_path']}

    pages.all.each do |page|
      puts "Preparando: #{page['path']}"

      meta = {
        titulo:       page['title'],
        subtitulo:    page['head'],
        imagen:       page['main_image']
      }
      content = clean_markdown(replace_image_paths(page['content'], replaces))

      path = clean_path("#{page['path']}.html.md")
      write(File.join(output, path), content, meta)
      #write(File.join(output, "#{page['path']}.yml"), YAML.dump(page))

    end
  end

  def write_redirect_data(file)
    ndx = {}
    pages.all.each {|p| ndx[p['path']] = clean_path(p['path']) }
    write(file, YAML.dump(ndx))
  end


  def dump(file)
    write(File.join(__dir__, 'pages.yml'), YAML.dump(pages.all))
  end

  def build_index(file)
    ndx = {}
    pages.all.each {|page| ndx[page['path']] = page['title']}

    content = ndx.keys.sort.map {|k| "| #{k} | #{ndx[k]} |"}.join("\n")
    write(file, "# Páginas\n\n#{content}")
  end

  private
  def build_path(page)
    if !blank?(page["name"]) && page["name"] != page["section"]
      path = "#{page["section"]}/#{page["name"]}"
    else
      page["section"]
    end
  end

  def clean_markdown(content)
    md = RedCloth.new(content)
    html = md.to_html.to_s.gsub(/[\n\t]+/, '')
    ReverseMarkdown.convert html
  end

  def replace_image_paths(content, replaces)
    content.gsub(/\/attachments\/0000\/[^!)]+/) do |path|
      match = path['attachments/0000/'.length + 1..-1]
      replace = replaces[match]
      if replace.nil?
        puts "ERROR: #{match} REPLACE NOT FOUND."
        "ERROR (imagen no encontrada): #{match}"
      else
        "/imagenes/#{replace}"
      end
    end
  end
end

# id,content_type,filename,size,tags,description,page_id,parent_id,thumbnail,width,height,db_file_id
class Images
  attr_reader :images, :pages

  def initialize(pages)
    @pages = pages
    @images = Repo.load('image', path('att.csv'))
    puts "#{@images.all.size} images loaded."
    process_images
  end

  def process_images
    dest = []

    images.all.each do |image|
      root_id = !blank?(image['parent_id']) ? image['parent_id'] : image['id']
      image['source_path'] = image_path(root_id) + "/" + image['filename']
      root_image = images.byId[root_id]
      image['root_page_id'] = root_image['page_id']
      page = pages.byId[image['root_page_id']]
      image['section'] = page ? page['section'] : 'otras'

      image['dest_path'] = image['section'] + "/" + parameterize(image['filename'])
      if dest.include?(image['dest_path'])
        image['dest_path'] = image['section'] + "/" + root_id + parameterize(image['filename'])
      end
      dest << image['dest_path']

      if image['tags'] == 'imágen_principal' && page
        image['page_title'] = page['title']
        page['main_image'] = image['dest_path']
      end
    end
  end


  def move_images(src, dest)
    create_sections(dest)

    moves = 0
    errors = 0
    images.all.each do |image|
      img_src = File.join(src, image['source_path'])
      img_dest = File.join(dest, image['dest_path'])

      if File.exist?(img_src)
        if File.exist?(img_dest)
          puts "ERROR dest exists: #{img_dest} // #{image}"
          errors += 1
        else
          #puts "MOVE IMAGE #{img_src} => #{img_dest}"
          FileUtils.mv(img_src, img_dest)
          moves += 1
        end
      else
        if !File.exists?(img_dest)
          puts "ERROR image src not found: #{img_src} // #{image}"
          errors +=1
        end
      end
    end
    puts "Moved #{moves}, errors #{errors}"
  end

  def build_index(file)
    cols = ['id', 'source_path', 'dest_path', 'page_title']
    output = images.all.map do |image|
      row = cols.map {|c| "#{c[0..2]}:#{image[c]}"}
      row.map {|i| "| #{i}"}.join(' ')
    end.join("\n")
    write(file, "# Imágenes\n\n#{output}")
  end

  def image_path(id)
    "0" * (4 - id.length) + id
  end
end

pagesRepo = Pages.new
imagesRepo = Images.new(pagesRepo.pages)
imagesRepo.build_index(path('../source/lista/imagenes.html.md'))
imagesRepo.move_images(path('../0000'), path('../publicar/imagenes'))
pagesRepo.export(imagesRepo.images, path('../publicar/paginas'))
pagesRepo.build_index(path('../source/lista/index.html.md'))
pagesRepo.write_redirect_data(path('redirects.yml'))
