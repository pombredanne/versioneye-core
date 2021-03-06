class CrawlerTask < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  field :poison_pill  , type: Boolean, default: false # Use it to kill crawler
  field :runs         , type: Integer, default: 0     # How many times crawled
  field :fails        , type: Integer, default: 0     # How many times failed
  field :task         , type: String                  # Task Type, classification. Use format <crawlers_name>/<task_name>
  field :task_failed  , type: Boolean, default: false
  field :re_crawl     , type: Boolean, default: false
  field :url          , type: String
  field :url_params   , type: Hash
  field :url_exists   , type: Boolean, default: false
  field :repo_owner   , type: String
  field :repo_name    , type: String
  field :repo_fullname, type: String
  field :registry_name, type: String
  field :tag_name     , type: String
  field :prod_key     , type: String
  field :weight       , type: Integer, default: 0 # To prioritize tasks
  field :data         , type: Hash                # Subdocument to keep pre-cached data
  field :crawled_at   , type: DateTime            # When it had last successful crawl

  scope :by_task      , ->(name){where(task: name)}
  scope :crawlable    , ->{ where(re_crawl: true, url_exists: true) }

  index({ task: 1 },          { name: "task_index"    , background: true })
  index({ task: 1, re_crawl: 1, url_exists: 1 }, { name: "task_recrawl_urlexists_index", background: true })
  index({ repo_fullname: 1 }, { name: "repo_fullname_index" , background: true })
  index({ task: 1, repo_fullname: 1 }, { name: "task_repo_fullname_index" , background: true })
  index({ task: 1, repo_fullname: 1, tag_name: 1 }, { name: "task_repo_fullname_tag_index" , background: true })
  index({ task: 1, repo_fullname: 1, prod_key: 1 }, { name: "task_repo_fullname_prod_key_index" , background: true })

end
