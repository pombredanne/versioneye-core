class Product < Versioneye::Model

  require 'versioneye/models/helpers/product_constants'
  include VersionEye::ProductConstants

  require 'versioneye/models/helpers/product_es_mapping'
  include VersionEye::ProductEsMapping

  include Mongoid::Document
  include Mongoid::Timestamps

  field :name         , type: String
  field :name_downcase, type: String
  field :prod_key     , type: String # Unique identifier inside a language
  field :prod_key_dc  , type: String # prod_key downcased .. important for NPM
  field :prod_type    , type: String # Identifies the package manager
  field :language     , type: String
  field :version      , type: String, default: '0.0.0+NA' # latest stable version
  field :sha1         , type: String
  field :sha256       , type: String
  field :md5          , type: String
  field :tags         , type: Array  # Array of keywords

  field :group_id   , type: String # Maven specific - GroupID lower case
  field :artifact_id, type: String # Maven specific - ArtifactId lower case
  field :parent_id  , type: String # Maven specific
  field :group_id_orig   , type: String # Maven specific
  field :artifact_id_orig, type: String # Maven specific

  field :description       , type: String
  field :description_manual, type: String

  field :downloads         , type: Integer, default: 0
  field :followers         , type: Integer, default: 0
  field :used_by_count     , type: Integer, default: 0 # Number of references, projects using this one.
  field :dep_count         , type: Integer, default: 0 # Number of direct dependencies.
  field :average_release_time, type: Integer, default: 0 # Number of average release dates.

  field :twitter_name, type: String

  field :reindex, type: Boolean, default: true # Trigger to reindex in ElasticSearch

  embeds_many :versions     # unsorted versions
  embeds_many :repositories

  has_and_belongs_to_many :users

  validates_presence_of :language , :message => 'language  is mandatory!'
  validates_presence_of :prod_type, :message => 'prod_type is mandatory!'
  validates_presence_of :prod_key , :message => 'prod_key  is mandatory!'
  validates_presence_of :name     , :message => 'name      is mandatory!'

  # For indexing use task: rake db:mongoid:create_indexes
  index({ prod_key:    1, language: 1 },    { name: "prod_key_language_index"   , unique: true, drop_dups: true, background: true })
  index({ prod_key_dc: 1, language: 1 },    { name: "prod_key_dc_language_index", unique: false, background: true })
  index({ group_id: 1, artifact_id: 1 }, { name: "group_id_artifact_id_index", background: true })
  index({ name: 1 },                     { name: "name_index", background: true })
  index({ name_downcase: 1 },            { name: "name_downcase_index", background: true })
  index({ prod_type: 1, name: 1 },       { name: "prod_type_name_index", background: true })
  index({ created_at: -1},               { name: "created_at_index", background: true})
  index({ updated_at: -1},               { name: "updated_at_index", background: true})
  index({ updated_at: -1, language: -1}, { name: "updated_language_index", background: true})
  index({ tags: 1},                      { name: "tags_index", background: true})

  attr_accessor :version_newest, :project_usage
  attr_accessor :released_days_ago, :released_ago_in_words, :released_ago_text
  attr_accessor :in_my_products, :dependencies_cache

  scope :by_language, ->(lang){where(language: lang)}


  def show_dependency_badge?
    A_LANGS_DEP_BADGE.include?(self.language)
  end

  def save(*arg)
    self.name_downcase = self.name.downcase if self.name
    super
  end

  def to_s
    "<Product #{language} / #{prod_key} (#{version}) >"
  end

  def to_param
    Product.encode_prod_key self.prod_key
  end

  def long_name
    if !group_id.to_s.empty? && !artifact_id.to_s.empty?
      return "#{group_id}:#{artifact_id}"
    end
    return name
  end

  def group_id_original
    return group_id_orig if !group_id_orig.to_s.empty?
    group_id
  end

  def artifact_id_original
    return artifact_id_orig if !artifact_id_orig.to_s.empty?
    return name if !name.to_s.empty?
    artifact_id
  end

  def add_tag tag_name
    self.tags = [] if tags.nil?
    self.tags.push( tag_name ) if !self.tags.include?( tag_name )
  end

  def remove_tag tag_name
    self.tags = [] if tags.nil?
    self.tags.delete( tag_name )
  end

  ######## SEARCH METHODS ####################

  def self.find_by_id id
    self.find id
  rescue => e
    log.error e.message
    nil
  end

  def self.fetch_product lang, key
    return nil if lang.to_s.strip.empty? || key.to_s.strip.empty?
    return Product.find_by_key( key ) if lang.eql? 'package'

    product = Product.find_by_lang_key( lang, key )
    product = Product.find_by_lang_key( lang, key.downcase ) if product.nil?
    product = Product.where(:language => lang, :prod_key_dc => key.downcase).first if ( product.nil? && lang.eql?( A_LANGUAGE_NODEJS ) )
    product
  end

  def self.fetch_bower name
    return nil if name.to_s.empty?

    product = Product.where(prod_type: Project::A_TYPE_BOWER, name: name).first
    product = Product.where(prod_type: Project::A_TYPE_BOWER, name_downcase: name.to_s.downcase).first if product.nil?
    product
  end

  # legacy, still used by fall back search and API v1.0
  def self.find_by_key searched_key
    Product.where(prod_key: searched_key).first
  end

  def self.find_by_lang_key language, searched_key
    Product.where(language: language, prod_key: searched_key).shift
  end

  def self.find_by_group_and_artifact group, artifact, language = nil
    return nil if group.to_s.strip.empty? || artifact.to_s.strip.empty?

    product = nil
    if language
      product = Product.where( group_id: group, artifact_id: artifact, language: language ).first
    end
    if product.nil?
      product = Product.where( group_id: group, artifact_id: artifact ).first
    end
    product
  end

  def self.by_prod_keys language, prod_keys
    if language.to_s.strip.empty? || prod_keys.nil? || prod_keys.empty? || !prod_keys.is_a?(Array)
      return Mongoid::Criteria.new(Product).where(:prod_key => "-1-1")
    end
    Product.where(:language => language, :prod_key.in => prod_keys)
  end

  ######## START VERSIONS ###################

  def sorted_versions
    Naturalsorter::Sorter.sort_version_by_method( versions, "version", false )
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    versions
  end

  def version_by_number searched_version
    versions.each do |version|
      return version if version.to_s.eql?( searched_version )
    end
    nil
  rescue => e
    log.error e
    nil
  end

  def versions_empty?
    versions.nil? || versions.size == 0 ? true : false
  end

  def add_version(version_string, hash = {})
    return nil if version_by_number(version_string)

    version_hash = {:version => version_string}
    version_hash = version_hash.merge(hash) if !hash.nil? and !hash.empty?
    version = Version.new(version_hash)
    versions.push( version )
    version.save
  end

  def remove_version version_string
    versions.each do |version|
      if version.to_s.eql?( version_string )
        version.remove
        self.version = sorted_versions.first.to_s
        self.save
        return true
      end
    end
    false
  end

  def add_repository src, repo_type = nil
    repositories.each do |repo|
      return nil if repo.src.eql?(src)
    end
    repo = Repository.new(:src => src, :repotype => repo_type )
    repositories.push( repo )
    repo.save
    save
  end

  def check_nil_version
    if versions && !versions.empty? && (version.nil? || version.eql?('0.0.0+NA'))
      self.version = sorted_versions.first
      self.save
    end
  end

  def add_svid version_number, sv
    version = version_by_number version_number
    return false if version.nil?
    return false if version.sv_ids.include?(sv.ids)

    version.sv_ids << sv.ids
    version.save
  end

  def remove_double_versions
    uv = []
    versions.each do |version|
      if uv.include?(version.to_s)
        p "remove #{version.to_s}"
        version.delete
      else
        p "add #{version.to_s}"
        uv.push version.to_s
      end
    end
    uv
  end

  ######## ENCODE / DECODE ###################

  def self.encode_prod_key prod_key
    return "0" if prod_key.to_s.strip.empty?
    prod_key.to_s.gsub('/', ':')
  end

  def self.decode_prod_key prod_key
    return nil if prod_key.to_s.strip.empty?
    prod_key.to_s.gsub(':', '/')
  end

  def self.encode_language language
    return nil if language.to_s.strip.empty?
    language.to_s.gsub("\.", "").downcase
  end

  def self.decode_language language
    return nil if language.to_s.strip.empty?
    return A_LANGUAGE_NODEJS       if language.match(/\Anode/i)
    return A_LANGUAGE_CSS          if language.match(/\ACSS/i)
    return A_LANGUAGE_PHP          if language.match(/\Aphp/i)
    return A_LANGUAGE_OBJECTIVEC   if language.match(/\AObjective-C/i)
    return A_LANGUAGE_JAVASCRIPT   if language.match(/\AJavaScript/i)
    return A_LANGUAGE_COFFEESCRIPT if language.match(/\ACoffeeScript/i)
    return A_LANGUAGE_ACTIONSCRIPT if language.match(/\AActionScript/i)
    return A_LANGUAGE_TYPESCRIPT   if language.match(/\ATypeScript/i)
    return A_LANGUAGE_LIVESCRIPT   if language.match(/\ALiveScript/i)
    return A_LANGUAGE_HTML         if language.match(/\Ahtml/i)
    return language.capitalize
  end

  def language_esc lang = nil
    lang = self.language if lang.nil?
    Product.encode_language lang
  end

  ########## ELSE #############

  def security_vulnerabilities
    version_obj = version_by_number( self.version )
    return nil if version_obj.nil?

    version_obj.security_vulnerabilities
  end

  def security_vulnerabilities_all
    SecurityVulnerability.where(:language => self.language, :prod_key => self.prod_key)
  end

  def update_in_my_products array_of_product_ids
    self.in_my_products = array_of_product_ids.include?(_id.to_s)
  end

  def released_at
    ver = version_by_number version
    return ver.released_at if ver
    ""
  end

  def description_summary
    if description && description_manual
      "#{description} \n \n #{description_manual}"
    elsif description && !description_manual
      return description
    elsif !description && description_manual
      return description_manual
    else
      ''
    end
  end

  def short_summary
    desc = description
    desc = description_manual if description_manual.to_s.length > description.to_s.length
    return get_summary( desc , 125)
  end

  def name_and_version
    "#{name} : #{version}"
  end

  def name_version limit
    nameversion = "#{name} (#{version})"
    if nameversion.length > limit
      "#{nameversion[0, limit]}.."
    else
      nameversion
    end
  end

  def license_info
    licenses = self.licenses false
    return 'unknown' if licenses.nil? || licenses.empty?
    licenses.map{|a| a.name_substitute}.join(', ')
  end

  def comments
    Versioncomment.find_by_prod_key_and_version(self.language, self.prod_key, self.version)
  end

  # An artifact (product + version) can have multiple licenses
  # at the same time. That's not a bug!
  def licenses ignore_version = false
    substitute_names = []
    licenses = []
    lics = License.for_product self, ignore_version
    consolidate_licenses lics, substitute_names, licenses

    lics = License.for_product_global self
    consolidate_licenses lics, substitute_names, licenses

    licenses
  end

  def licenses_all ignore_version = false
    licenses = []
    lics1 = License.for_product self, true
    lics2 = License.for_product_global self
    lics1.each do |license|
      licenses << license
    end
    lics2.each do |license|
      licenses << license
    end
    licenses
  end

  def developers
    Developer.find_by self.language, self.prod_key, self.version
  end

  def dependencies scope = nil
    dependencies_cache ||= {}
    scope = Dependency.main_scope( self.language, self.prod_type ) unless scope
    if dependencies_cache[scope].nil?
      dependencies_cache[scope] = Dependency.find_by_lang_key_version_scope( language, prod_key, version, scope )
    end
    dependencies_cache[scope]
  end

  def all_dependencies( version = nil )
    version = self.version if version.to_s.empty?
    Dependency.find_by_lang_key_and_version( language, prod_key, version)
  end

  # Returns the links which belong to the product and are not
  # bounded to a specific verison of the product.
  # For example link to project homepage.
  def http_links
    links = Versionlink.where(language: language, prod_key: self.prod_key, version_id: nil).asc(:name)
    get_http_links links
  end

  # Returns the links which are bounded to a specific version
  # of the product.
  # For example link to an artifact or a migration path.
  def http_version_links
    links = Versionlink.where(language: language, prod_key: self.prod_key, version_id: self.version ).asc(:name)
    get_http_links links
  end

  # Returns all links which are bounded to a specific version AND
  # the product links which are not bounded to a specific version.
  def http_version_links_combined
    links_1 = http_links
    links_2 = http_version_links
    links_1 << links_2
    links_1.flatten!
    uniq_names = {}
    response = {}
    links_1.each do |link|
      if (!uniq_names.keys.include?(link.name) ||
          (uniq_names.keys.include?(link.name) && uniq_names[link.name].utc < link.updated_at.utc ) )
        uniq_names[link.name] = link.updated_at
        response[link.name] = link
      end
    end
    response.values
  end

  def archives
    Versionarchive.archives( self.language, self.prod_key, self.version.to_s )
  end

  def self.unique_languages_for_product_ids(product_ids)
    Product.where(:_id.in => product_ids).distinct(:language)
  end

  def to_url_path
    "/#{language_esc}/#{to_param}"
  end

  def version_to_url_param
    Version.encode_version version
  end

  def main_scope
    Dependency.main_scope self.language
  end

  def auditlogs
    Auditlog.where(:domain_id => self.id.to_s).desc(:created_at)
  end

  def scm_changelogs
    ScmChangelogEntry.where(:language => language, :prod_key => prod_key, :version => version)
  end

  private

    def consolidate_licenses lics, substitute_names, licenses
      return if lics.nil? || lics.empty?

      lics.each do |license|
        if !substitute_names.include?( license.name_substitute )
          substitute_names << license.name_substitute
          licenses << license
        end
      end
    end

    def get_summary text, size
      return '' if text.nil?
      return "#{text[0..size]}..." if text.size > size
      text[0..size]
    end

    def get_http_links links
      result = []
      return result if links.nil? || links.empty?

      links.each do |link|
        next if link.nil?
        next if link.link.to_s.empty?
        next if link.link.match(/\Ahttp*/i) == nil

        if !link.to_s.match("search.maven.org") && !self.group_id.to_s.empty? && link.to_s.match(self.group_id)
          link.link = link.to_s.gsub( self.group_id , self.group_id.gsub(/\./, "/") )
        end

        result << link
      end
      result
    end

end
