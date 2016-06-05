class Project < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  A_TYPE_RUBYGEMS  = 'RubyGem'
  A_TYPE_PIP       = 'PIP'
  A_TYPE_NPM       = 'npm'
  A_TYPE_COMPOSER  = 'composer'
  A_TYPE_GRADLE    = 'gradle'
  A_TYPE_SBT       = 'sbt'
  A_TYPE_MAVEN2    = 'Maven2'
  A_TYPE_LEIN      = 'Lein'
  A_TYPE_BOWER     = 'Bower'
  A_TYPE_GITHUB    = 'GitHub'
  A_TYPE_R         = 'R'
  A_TYPE_COCOAPODS = 'CocoaPods'
  A_TYPE_BIICODE   = 'Biicode'
  A_TYPE_CHEF      = 'Chef'

  A_SOURCE_UPLOAD    = 'upload'
  A_SOURCE_URL       = 'url'
  A_SOURCE_GITHUB    = 'github'
  A_SOURCE_BITBUCKET = 'bitbucket'
  A_SOURCE_STASH     = 'stash'
  A_SOURCE_API       = 'API'

  A_PERIOD_MONTHLY = 'monthly'
  A_PERIOD_WEEKLY  = 'weekly'
  A_PERIOD_DAILY   = 'daily'

  field :name         , type: String
  field :name_downcase, type: String # downcased name, because MongoDB doesn't support case insensitive search.
  field :description  , type: String
  field :license      , type: String
  field :version      , type: String
  field :packaging    , type: String

  field :group_id   , type: String # Maven specific
  field :artifact_id, type: String # Maven specific

  field :language      , type: String
  field :project_type  , type: String,  :default => A_TYPE_MAVEN2
  field :period        , type: String,  :default => A_PERIOD_DAILY
  field :notify_after_api_update, type: Boolean, :default => false

  field :email         , type: String
  field :url           , type: String
  field :source        , type: String,  :default => A_SOURCE_UPLOAD
  field :s3_filename   , type: String

  field :scm_fullname  , type: String # repo name, for example 'reiz/gemify'
  field :scm_branch    , type: String, default: "master"
  field :scm_revision  , type: String

  field :dep_number      , type: Integer, :default => 0
  field :out_number      , type: Integer, :default => 0
  field :unknown_number  , type: Integer, :default => 0
  field :licenses_red    , type: Integer, :default => 0
  field :licenses_unknown, type: Integer, :default => 0
  field :sv_count        , type: Integer, :default => 0

  # These are the numbers summed up from all children
  field :dep_number_sum      , type: Integer, :default => 0
  field :out_number_sum      , type: Integer, :default => 0
  field :unknown_number_sum  , type: Integer, :default => 0
  field :licenses_red_sum    , type: Integer, :default => 0
  field :licenses_unknown_sum, type: Integer, :default => 0
  field :sv_count_sum        , type: Integer, :default => 0

  field :temp           , type: Boolean, :default => false  # temporary project. if true it doesn't show up in the UI and will be removed by a background job.
  field :public         , type: Boolean, :default => false  # visible for everybody
  field :private_project, type: Boolean, :default => false  # private project from GitHub/Bitbucket
  field :parent_id      , type: String,  :default => nil    # id of the parent project.

  field :license_whitelist_id, type: String
  field :component_whitelist_id, type: String

  field :parsing_errors , type: Array, :default => []

  validates :name       , presence: true

  belongs_to :user
  belongs_to :organisation
  has_many   :projectdependencies
  has_and_belongs_to_many :teams

  index({user_id: 1, private_project: 1},  { name: "user_id_private_index", background: true})
  index({user_id: 1}, { name: "user_id_index", background: true})
  index({name: 1},    { name: "name_index",    background: true})
  index({source: 1},  { name: "source_index",  background: true})

  scope :by_user   , ->(user)    { where(user_id: user[:_id].to_s) }
  scope :by_user_id, ->(user_id) { where(user_id: user_id.to_s) }
  scope :by_id     , ->(id)      { where(_id: id.to_s) }
  scope :by_source , ->(source)  { where(source:  source ) }
  scope :by_period , ->(period)  { where(period:  period ) }
  scope :parents   , -> { where(parent_id: nil ) }
  scope :by_github , ->(reponame){ where(source: A_SOURCE_GITHUB, scm_fullname: reponame) }

  attr_accessor :lwl_pdf_list # list of dtos for the License Whitelist PDF
  attr_accessor :sec_pdf_list # list of dtos for the Security PDF
  attr_accessor :has_kids

  before_save :perpare_name_for_search

  def to_s
    "<Project #{language}/#{project_type} #{name}>"
  end

  def ids
    id.to_s
  end

  def parent
    return Project.find(parent_id) if parent_id
    return nil
  end

  def children
    Project.where(:parent_id => self.id.to_s)
  end

  def scopes
    return [] if self.projectdependencies.nil? || self.projectdependencies.empty?
    scopes = []
    self.projectdependencies.each do |dependency|
      scopes << dependency.scope if !scopes.include?( dependency.scope )
    end
    scopes
  end

  def dependencies(scope = nil)
    return self.projectdependencies if scope.nil?
    return self.projectdependencies if self.projectdependencies.nil? || self.projectdependencies.empty?
    deps = []
    self.projectdependencies.each do |dependency|
      deps << dependency if dependency.scope.eql?(scope)
    end
    deps
  end

  def sorted_dependencies_by_rank( deps = nil )
    deps = self.dependencies if deps.nil?
    return deps if deps.nil? or deps.empty?
    deps.sort_by {|dep| dep[:status_rank] }
  end

  def unmuted_dependencies
    deps = self.projectdependencies
    return nil if deps.nil?
    deps.any_in(muted: [false, nil])
  end

  def muted_dependencies
    deps = self.projectdependencies
    return nil if deps.nil?
    deps.any_in(muted: [true])
  end

  def muted_dependencies_count
    deps = muted_dependencies
    return 0 if deps.nil?
    deps.count
  end

  def self.find_by_id( id )
    Project.find( id )
  rescue => e
    log.error e.message
    log.error e.backtrace.join("\n")
    nil
  end

  def self.find_by_ga( group_id, artifact_id )
    Project.where(:group_id => group_id, :artifact_id => artifact_id).first
  end

  def self.find_by_gav( group_id, artifact_id, version )
    Project.where(:group_id => group_id, :artifact_id => artifact_id, :version => version ).first
  end

  def filename
    self.s3_filename.to_s.gsub(/\A\S+\_/, "")
  end

  def self.private_project_count_by_user user_id
    Project.where( user_id: user_id, private_project: true ).count
  end

  def show_dependency_badge?
    true
  end

  def visible_for_user?(user)
    return false if user.nil?
    return true  if self[:public]
    return true  if user.admin
    return true  if self.user_id.to_s.eql?(user.ids)
    return true  if is_orga_member?(user)
    return false
  end

  def is_collaborator?( user )
    return false if user.nil?
    return true if self.user_id.to_s.eql?(user.ids)
    return true if organisation && OrganisationService.owner?( organisation, user ) == true

    if teams && !teams.empty?
      teams.each do |team|
        team.members.each do |tm|
          return true if tm.user.ids.eql?(user.ids)
        end
      end
    end

    false
  end

  def is_orga_member?(user)
    if organisation
      return OrganisationService.member?( organisation, user )
    end
    false
  end

  def license_whitelist
    return nil if license_whitelist_id.to_s.empty?
    LicenseWhitelist.find license_whitelist_id
  rescue => e
    log.error e.message
    nil
  end

  def license_whitelist_name
    lwl = license_whitelist
    return lwl.name if lwl
    nil
  end

  def unknown_license_deps
    deps = []
    projectdependencies.each do |dep|
      if (dep.license_caches.nil? || dep.license_caches.to_a.empty?) || (dep.license_caches.count == 1 && dep.license_caches.first.name.casecmp('unknown') == 0)
        deps.push(dep)
      end
    end
    deps
  end

  def component_whitelist
    return nil if component_whitelist_id.to_s.empty?
    ComponentWhitelist.find component_whitelist_id
  rescue => e
    log.error e.message
    nil
  end

  def component_whitelist_name
    cwl = component_whitelist
    return cwl.name if cwl
    nil
  end

  def known_dependencies
    self.projectdependencies.find_all {|dep| dep.prod_key }
  end

  def remove_dependencies
    Projectdependency.where(:project_id => self.ids).each do |dep|
      dep.delete
    end
    projectdependencies.clear
  end

  def save_dependencies
    projectdependencies.each { |dependency| dependency.save }
  end

  def muted_prod_keys
    prod_keys = Array.new
    mute_messages = {}
    muted_deps = muted_dependencies
    muted_deps.each do |dep|
      key = dep_key(dep)
      prod_keys << key
      mute_messages[key] = dep.mute_message
    end
    {:keys => prod_keys, :messages => mute_messages}
  end

  def update_from new_project
    return nil if new_project.nil?

    self.dep_number     = new_project.dep_number
    self.out_number     = new_project.out_number
    self.unknown_number = new_project.unknown_number
    self.description    = new_project.description
    self.license        = new_project.license
    self.url            = new_project.url
    if new_project.s3_filename
      self.s3_filename  = new_project.s3_filename
    end
    self.updated_at = Time.now

    self.overwrite_dependencies( new_project.projectdependencies )

    self.save
  end

  def overwrite_dependencies( new_dependencies )
    return nil if new_dependencies.nil? || new_dependencies.empty?
    muted_deps    = muted_prod_keys
    muted_keys    = muted_deps[:keys]
    mute_messages = muted_deps[:messages]
    remove_dependencies
    new_dependencies.each do |dep|
      key = dep_key(dep)
      if muted_keys.include?( key )
        dep.muted = true
        dep.mute_message = mute_messages[key]
        dep.outdated = false
        dep.outdated_updated_at = DateTime.now
        self.out_number = self.out_number.to_i - 1
      end
      projectdependencies.push dep
      dep.save
    end
  end

  def self.email_for(project, user)
    return user.email if project.email.to_s.empty?

    user_email = user.get_email( project.email )
    return user_email.email if user_email && user_email.verified?

    return user.email
  end

  def self.create_random_value
    chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    value = ""
    20.times { value << chars[rand(chars.size)] }
    value
  end

  def sum_own!
    self.dep_number_sum       = self.dep_number
    self.out_number_sum       = self.out_number
    self.unknown_number_sum   = self.unknown_number
    self.licenses_red_sum     = self.licenses_red
    self.licenses_unknown_sum = self.licenses_unknown
    self.sv_count_sum         = self.sv_count
    self.save
  end

  def sum_reset!
    self.dep_number_sum       = 0
    self.out_number_sum       = 0
    self.unknown_number_sum   = 0
    self.licenses_red_sum     = 0
    self.licenses_unknown_sum = 0
    self.sv_count_sum         = 0
    self.save
  end

  def get_binding
    binding()
  end

  def auditlogs
    Auditlog.where(:domain_id => self.ids).desc(:created_at)
  end

  private

    def dep_key dep
      "#{dep.language}_#{dep.prod_key}_#{dep.version_current}"
    end

    def perpare_name_for_search
      self.name_downcase = self.name.downcase
    end

end
