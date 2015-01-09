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

TILDES = {'a' => 'à', 'e' => 'é', 'i' => 'í', 'o' => 'ó', 'u' => 'ú'}
def parameterize(string)
  string = string.downcase.gsub(' ','_').gsub('-', '_')
  #TILDES.each {|k, v| string.gsub!(v, k) }
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
  end

  def export(output)
    mkdir(output)

    pages.all.each do |page|
      path = prepare_path(page, output)
      write_template(page, File.join(output, "#{path}.html.md"))
      write_data(page, File.join(output, "#{path}.yml"))
    end
  end

  def prepare_path(page, output)
    path = page["section"]
    if !blank?(page["name"]) && page["name"] != page["section"]
      dir = File.join(output, page['section'])
      mkdir(dir)
      path = "#{path}/#{page["name"]}"
    end
    path
  end

  def write_template(page, file)
    puts "Procesando: #{file}"
    meta = {
      titulo:       page['title'],
      subtitulo:    page['head'],
      imagen:       page['main_image']
    }

    File.open(file, 'w') do |file|
      file.write("---\n")
      meta.each do |key, value|
        val = value ? value.gsub(/[\n]+/, '') : ''
        file.write("#{key}: \"#{val}\"\n")
      end
      file.write("---\n")
      file.write(render(page))
    end
  end

  def write_data(page, file)
    File.open(file, 'w') do |file|
      file.write(YAML.dump(page))
    end
  end

  def render(page)
    md = RedCloth.new(page['content'])
    html = md.to_html.to_s.gsub(/[\n\t]+/, '')
    ReverseMarkdown.convert html
  end

  def dump(file)
    File.open(File.join(__dir__, 'pages.yml'), 'w') do |file|
      file.write(YAML.dump(pages.all))
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

  def move_images(dest)
    SECTIONS = ['inicio', 'websamigas', 'conferencias', 'paraleer', 'mislibros', 'premios', 'biografia',
      'encuentros', 'matematicas', 'contacto', 'elsahara']
    SECTIONS.each {|s| mkdir(File.join(dest, s)) }
  end


  def build_index(file)
    File.open(file, 'w') do |file|
      file.write("# Imágenes\n\n")
      cols = ['id', 'source_path', 'dest_path', 'page_title']
      images.all.each do |image|
        row = cols.map {|c| "#{c[0..2]}:#{image[c]}"}
        render = row.map {|i| "| #{i}"}.join(' ')
        file.write("#{render}\n")
      end
    end
  end

  def image_path(id)
    "0000/" + "0" * (4 - id.length) + id
  end
end

pagesRepo = Pages.new
imagesRepo = Images.new(pagesRepo.pages)
imagesRepo.build_index(path('../source/images_index.html.md'))
imagesRepo.move_images(path('../publicar/imagenes'))
#pagesRepo.export(path('../publicar/paginas'))
