require 'bundler/setup'
require 'nokogiri'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'
require 'uri'
require 'digest'
require 'set'

API_VERSION = 'v2'
CREDENTIAL_STORE_FILE = "convert-oauth2.json"
CACHED_API_FILE = "drive-#{API_VERSION}.cache"

OUTPUT_DIR='latex/'


@use_chapters = true #TODO: Options parsing
@replace_backslash_in_formulas = true
@image_caption = nil
@numbered_equations = true

@mode = 'normal'

@styles = {}

def setup
  client = Google::APIClient.new(
    :application_name => 'LaTeX Converter',
    :application_version => '0.1'
  )

  # FileStorage stores auth credentials in a file, so they survive multiple runs
  # of the application. This avoids prompting the user for authorization every
  # time the access token expires, by remembering the refresh token.
  # Note: FileStorage is not suitable for multi-user applications.
  file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
  if file_storage.authorization.nil?
    client_secrets = Google::APIClient::ClientSecrets.load
    # The InstalledAppFlow is a helper class to handle the OAuth 2.0 installed
    # application flow, which ties in with FileStorage to store credentials
    # between runs.
    flow = Google::APIClient::InstalledAppFlow.new(
      :client_id => client_secrets.client_id,
      :client_secret => client_secrets.client_secret,
      :scope => ['https://www.googleapis.com/auth/drive']
    )
    client.authorization = flow.authorize(file_storage)
  else
    client.authorization = file_storage.authorization
  end

  drive = nil
  # Load cached discovered API, if it exists. This prevents retrieving the
  # discovery document on every run, saving a round-trip to API servers.
  if File.exists? CACHED_API_FILE
    File.open(CACHED_API_FILE) do |file|
      drive = Marshal.load(file)
    end
  else
    drive = client.discovered_api('drive', API_VERSION)
    File.open(CACHED_API_FILE, 'w') do |file|
      Marshal.dump(drive, file)
    end
  end

  return client, drive
end

def friendly_filename(filename)
  filename.gsub(/[^\w\s_-]+/, '')
  .gsub(/(^|\b\s)\s+($|\s?\b)/, '\\1\\2')
  .gsub(/\s+/, '_')
end

def download_file(client, download_url)
  result = client.execute(:uri=>download_url)
  if result.status == 200
    return result.body
  else
    puts "Could not download #{download_url}: #{result.data['error']['message']}"
    exit 1
  end
end

def download_image(client, download_url)
  result = client.execute(:uri=>download_url)
  if result.status == 200
    content_type = result.media_type
    ext = ""
    case content_type
    when "image/png"
      ext = ".png"
    when "image/jpeg"
      ext = ".jpg"
    end
    filename = Digest::MD5.hexdigest(download_url) + ext
    file = File.open("#{OUTPUT_DIR}#{filename}", 'w')
    file.write(result.body)
    file.close
    filename
  else
    puts "Could not download #{download_url}: #{result.data['error']['message']}"
    exit 1
  end
end

def parse_references
  @references = Set.new
  if File.exists?(@bibtex_file)
    bib = File.open(@bibtex_file, 'r')
    bib.each_line do |line|
      if line.match /@.+{(.+),/
        @references.add $1
      end
    end
    bib.close
  end
end

def add_reference(title, content)
  unless @references.add?(title).nil?
    puts "Add reference: #{title} => #{content}"
    bib = File.open(@bibtex_file, 'a')
    bib.puts "@article{#{title},"
    bib.puts "\t#{content}"
    bib.puts "}\n"
    bib.close
  end
end

def parse_style(klass)
  return @styles[klass] if @styles[klass]

  if @style.match(/\.#{klass}\{(.+?)\}/)
    style = nil
    case $1
      when "font-weight:bold"
        style = "\\textbf{"
      when "font-style:italic"
        style = "\\textit{"
      when "text-decoration:underline"
        style ="\\underline{"
      else
        puts "Unknown style #{$1}"
    end
    @styles[klass] = style
  else
    @styles[klass] = nil
  end

  return @styles[klass]
end

def parse_formula(input)
  ret = URI::decode(input).gsub("\\+","")
  ret.gsub!("\\backslash", "\\") if @replace_backslash_in_formulas
  ret
end

def parse_node(client, node, alone_in_p=false)
  text_start = ""
  text_end = ""
  post_process = Proc.new {|text| text }
  pre_append_process = Proc.new {|text| text }

  case node.node_name
  when /h([1-9])/
    h_num = $1.to_i
    text_start = "\\" + (h_num - (@use_chapters ? 2 : 1)).times.collect{"sub"}.join + "section {"

    text_start = "\\chapter {" if h_num == 1 && @use_chapters

    text_end = "}\n"
    post_process = Proc.new do |text|
      postfix = ""
      nonumber = false
      text.gsub!(/\[label:(.*)\]/) { |match|
        postfix = "\\label{#{$1}}"
        ""
      }
      text.gsub!(/\[nonumber\]/) { |match|
        nonumber = true
        ""
      }

      text.gsub!(/\{/, "*{") if nonumber

      "#{text}#{postfix}"
    end
  when "p"
    text_start = ""
    text_end = "\n"
    if node.children.count == 1 && node.children[0].name == "img"
      return parse_node(client, node.children[0], true)
    elsif node['class'].match(/title/)
      subcontent = node.children.collect{|n| parse_node(client, n).strip}.join.strip
      if node['class'].match(/subtitle/)
        @document_subtitle = subcontent
      else
        @document_title = subcontent
      end
      return ""
    end

    post_process = Proc.new { |text|
      text.gsub(/[\u201c\u201d"]/, "''").gsub(/\{cite:(.+?)\}/, '~\\cite{\1}').gsub(/\[ref:(.+?)\]/, '~\\ref{\1}').gsub(/\[image_caption:(.+?)\]/) do |match|
        @image_caption = $1
        ""
      end

    }
  when "span"
    text_start = " "
    text_end = " "
    if !node['class'].nil?
      node['class'].split(" ").each do |klass|
        style = parse_style(klass)
        unless style.nil?
          text_start = "#{style}#{text_start}"
          text_end = "}#{text_end}"
        end
      end
    end
    pre_append_process = Proc.new { |text| text.strip }
  when "text"
    if node.content.strip == "<abstract>"
      @mode = 'abstract'
    elsif node.content.strip == "</abstract>"
      @mode = 'normal'
    elsif node.content.strip == "<references>"
      @mode = 'references'
      parse_references
    elsif node.content.strip == "</references>"
      @mode = 'normal'
      text_end = "\\bibliography{#@base_name}\n"
    else
      text_start = node.content.strip
      text_end = ""
    end
  when "a"
    unless (href = node['href']).nil? || href == "#"
      return "\\url{#{href}}" # We have to hack this, since we can't handle content and url in a text document
    else
      # maybe handle achoring here?
      text_start = ""
      text_end = ""
    end
  when "img"
    src = node['src']
    if src =~ /^https:\/\/www.google.com\/chart\?.*chl=(.+)/
      if alone_in_p && @numbered_equations
        return "\\begin{equation}\n"+parse_formula($1)+"\n\\end{equation}\n"
      elsif alone_in_p
        return " $$"+parse_formula($1)+" $$"
      else
        return " $"+parse_formula($1) + "$ "
      end
    else
      image_name = download_image(client, src)
      ret = "\\begin{figure}[ht]
        \\begin{center}
        \\includegraphics[width=\\textwidth]{#{image_name}}
#{@image_caption.nil? ? "" : "   \\caption{\\small{#@image_caption}}"}
        \\label{#{image_name}}
        \\end{center}
      \\end{figure}"
      @image_caption = nil
      return ret
    end
  when "table"
    # Find count:
    count = node.css("tr").first.css("td").count
    text_start = "\\begin{tabular}{ #{count.times.collect{"l "}.join}}\n"
    text_end = "\n\\end{tabular}\n"
  when "tbody"
    text_start = ""
    text_end = ""
  when "tr"
    text_start = ""
    text_end = "\\\\\n"
    pre_append_process = Proc.new { |text|
      text.slice!(text.rindex("&"), 1)
      text
    }
  when "td"
    text_start = " "
    text_end = " &"
  when "ul"
    text_start = "\\begin{itemize}\n"
    text_end = "\n\\end{itemize}\n"
  when "ol"
    text_start = "\\begin{enumerate}\n"
    text_end = "\n\\end{enumerate}\n"
  when "li"
    if @mode == 'references'
      raw = node.children.collect{|n| parse_node(client, n)}.join.strip
      colon_index = raw.index(":")
      if colon_index.nil?
        title = raw
        content = ""
      else
        #puts "Reference: raw: #{raw}, colon_index: #{colon_index}"
        title = raw[0..(colon_index-1)].strip
        content = raw[(colon_index + 1)..-1].strip
      end
      add_reference(title, content)
    else
      text_start = "\\item "
      text_end = "\n"
    end
  else
    puts "Unhandled node type #{node.name}"
  end

  post_process.call(text_start + pre_append_process.call(node.children.collect{|n| parse_node(client, n)}.join.strip) + text_end)
end

template_file = "default.tex"

if ARGV.length < 1
  puts "Usage: ./convert.rb gdrive_file_id [template.tex]"
  exit
else
  file_id = ARGV[0]
  template_file = ARGV[1] if ARGV.length == 2
end

client, drive = setup

result = client.execute api_method: drive.files.get, parameters: { 'fileId' => file_id }

file = result.data

@document_title = file.title
@document_subtitle = ""
@abstract = ""

puts "Converting #{file.title} [template: #{template_file}]"

template = File.open(template_file, 'r')


@base_name = friendly_filename(file.title).downcase
filename = "#{OUTPUT_DIR}#@base_name.tex"
@bibtex_file = "#{OUTPUT_DIR}#@base_name.bib"

puts file.exportLinks['text/html']

html_content = download_file(client, file.exportLinks['text/html'])

# Debug write
html_out = File.open("temp.html", 'w')
html_out.puts html_content
html_out.close
#end Debug write

doc = Nokogiri::HTML(html_content)

content = ""

@style = ""

doc.css('head').css('style').each do |node|
  @style = "#{@style}#{node.children[0].to_s}"
end

doc.css('body').children.each do |node|
  node_content = parse_node(client, node)
  if @mode == 'normal'
    content = "#{content}#{node_content}"
  elsif @mode == 'abstract'
    @abstract = "#{@abstract}#{node_content}"
  else
    # Ignore other modes
  end
end

puts "Warning, missing <#@mode> end tag" if @mode != 'normal'

content = content.gsub(/\n{3,}/, "\n\n").gsub(/[ \t]{2,}/, " ")

replace_map = {
  'title' => @document_title,
  'subtitle' => @document_subtitle,
  'author' => file.lastModifyingUserName,
  'yield' => content,
  'abstract' => @abstract
}

# Begin output and template parsing
out = File.open(filename, 'w')

template.each_line do |line|
  out.puts(line.gsub(/#\{([^}]+)\}/) do |match|
    if replace_map[$1]
      replace_map[$1]
    else
      "[Invalid data block]"
    end
  end)
end

puts "Wrote #{filename}"
