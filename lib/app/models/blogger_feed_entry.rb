# == Schema Information
# Schema version: 20100830082032
#
# Table name: blogger_feed_entries
#
#  id                  :integer(4)      not null, primary key
#  blogger_feed_id     :integer(4)
#  entry_id            :string(255)
#  title               :string(255)
#  link_self_href      :string(255)
#  link_alternate_href :string(255)
#  etag                :string(255)
#  content             :text
#  clean_url_id        :string(250)
#  summary             :text
#  published           :datetime
#  updated             :datetime
#
class BloggerFeedEntry < ActiveRecord::Base
  
  belongs_to :blogger_feed
  validates_uniqueness_of :clean_url_id
  validates_format_of :clean_url_id, :with => /^(([a-z0-9]|-)+)$/, 
      :message => 'is invalid. The clean_url_id must be only downcased letters [a-z], numbers [0-9] and minus symbol (-). Example: my-1st-valid-id'
  validates_length_of :clean_url_id, :maximum => 250 # Está alineado con el :limit => 250 de la columna creada en la migration
  
  # will_paginate. Número de entradas por defecto al mostrarse con paginate, por ejemplo: @blogger_feed.entries.paginate(:page => params[:page])
  cattr_reader :per_page
  @@per_page = 7
  
  before_validation :autoset_clean_url_id_from_title
  
  # Equivalencia entre un RSS::Atom::Feed::Entry
  # y los atributos de este modelo
  def self.attributes_from_xml_atom_feed_entry(entry)
    content = entry.elements['content'] ? entry.elements['content'].text : (entry.elements['summary'] ? entry.elements['summary'].text : '')
    summary = entry.elements['summary'] ? entry.elements['summary'].text : BloggerFeedEntry.content_brief(content)
    
    attrs = {
      :entry_id            => entry.elements['id'].text, # /feed/entry/id
      :title               => entry.elements['title'].text, # /feed/entry/title
      :etag                => entry.attribute('gd:etag').value, # /feed/entry/@gd:etag
      :content             => content, # /feed/entry/content (aunque si es vacío, pilla del summary, o nada.)
      :summary             => summary, # /feed/entry/summary (aunque si es vacío, recorta el content usando el helper brief.)
      
      :published           => DateTime.parse(entry.elements['published'].text.to_s),  # /feed/entry/published (RFC 3339 format)
      :updated             => DateTime.parse(entry.elements['updated'].text.to_s),    # /feed/entry/updated (RFC 3339 format)
    }
    
    entry.elements.each('link') do |link|
      attrs[:link_self_href]      = link.attribute('href').value if link.attribute('rel').value == 'self' # /feed/entry/link[[]@rel="self"]/@href
      attrs[:link_alternate_href] = link.attribute('href').value if link.attribute('rel').value == 'alternate' and link.attribute('type').value == 'text/html' # /feed/entry/link[[]@rel="alternate"][[]@type="text/html"]/@href
    end
    
    attrs
  end
  
  # Enlace al post en Blogger
  def link
    link_alternate_href
  end
  
  # Identificador del post dentro del blog de blogger. Es similar al blogger_feed.blog_id, pero para esta entrada.
  def blog_post_id
    # entry_id es un String del estilo: "tag:blogger.com,1999:blog-8729418600058975404.post-7054694034042650871"
    # del cual nos queremos quedar con el código numérico que va después de ".post-":
    # "tag:blogger.com,1999:blog-8729418600058975404.post-7054694034042650871".match(/.post-(\d+)/)[1] #=> "7054694034042650871"
    entry_id.match(/.post-(\d+)/)[1]
  end
  
  # Devuelve la ruta a una imagen que puede aparecer como thumbnail en la vista reducida de las entradas.
  # Mira en el content el primer tag img que encuentre y se queda con el valor de su atributo src.
  # Por ello, si se quiere poner un thumbnail concreto a propósito, lo mejor es añadir en el post una imagen al principio
  # que tenga style="display: none;", así no se verá en el contenido, pero sí en el thumbnail, por ejemplo:
  #   <img src="http://teimas.com/images/teixo_260.png?1275043018" style="display:none" />
  # Así tambien se puede hacer para cargar imáenes que sean del tamaño adecuado (max 80x120px) y mejorar el rendimiento de la vista.
  def thumbnail_image_src
    unless @thumbnail_image_src
      img_srcs = []
      img_srcs += content.scan /src\s*=\s*"([^"]+)"/i # busca src="img_src" (comillas dobles)
      img_srcs += content.scan /src\s*=\s*'([^']+)'/i # busca src='img_src' (comillas simples)
      img_srcs.flatten!
      img_srcs.reject!{ |src| src[0..44] == 'https://blogger.googleusercontent.com/tracker'} # por alguna razón en los contenidos se incluye una imagen que redirige a un tracker.
      @thumbnail_image_src = img_srcs.first # devolvemos simplemente la primera de las encontradas
    end
    @thumbnail_image_src
  end
  
  # Fija el valor del identificador clean_url_id
  # Si encuentra que ya hay otra entry con el mismo clean_url_id le concatena el entry_id,
  # de esa forma nos aseguramos que tiene un clean_url_id único (siempre que entry_id tenga su valor correcto, que por ahora vale).
  def autoset_clean_url_id_from_title
    if self.clean_url_id.blank?
      self.clean_url_id = self.title.parameterize
      if BloggerFeedEntry.find_by_clean_url_id(self.clean_url_id)
        self.clean_url_id = "#{self.clean_url_id}-#{self.entry_id}".parameterize
      end
    end
    # Eliminar simbolos "+", que permite parameterize pero no los queremos
    self.clean_url_id.gsub!('+', '-')
  end
  
  # Recorta el texto
  def self.content_brief(text)
    max_length = 300
    end_with = '...'
    text = helpers.strip_tags(text.gsub(/<\s*br\s*\/?>/i, ' ')) # take html tags away, with the special behaviour ofconverting <br> into spaces (More clear output).
    
    text = if text.length > max_length
      max_length += 1 # we need to check one more character for whitespaces (so don't cut words)
      text = text[0...max_length] # cut text
      text = text[0..text.rindex(/[^\w]/)] # dispose the last word if is incomplete
      text + end_with
    else
      text
    end
    
    text.gsub('&nbsp;', ' ').gsub('&quot;', '"') # replace most common html special characters 
  end
  
  # Workaround para poder usar el 'helper' strip_tags() en el modelo,
  # para pooder recortar el content en caso de que no se proporcione un summary automáticamente.
  # See http://railscasts.com/episodes/132-helpers-outside-views
  def self.helpers
    ActionController::Base.helpers
  end
  
end
