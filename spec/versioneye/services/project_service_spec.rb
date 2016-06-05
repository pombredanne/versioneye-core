require 'spec_helper'

describe ProjectService do

  let(:github_user) { FactoryGirl.create(:github_user)}

  describe "index" do
    it 'returns the single project for a user' do
      user = UserFactory.create_new
      project = ProjectFactory.create_new user
      project.save
      expect( ProjectService.index(user).count ).to eq(1)
    end
    it 'returns the single parent project for a user' do
      user = UserFactory.create_new
      project = ProjectFactory.create_new user
      project.save
      project2 = ProjectFactory.create_new user
      project2.parent_id = project.ids
      project2.save
      expect( ProjectService.index(user).count ).to eq(1)
    end
    it 'returns 2 projects for a user' do
      user = UserFactory.create_new
      project = ProjectFactory.create_new user
      project.save
      project2 = ProjectFactory.create_new user
      project2.save
      expect( ProjectService.index(user).count ).to eq(2)
    end
    it 'returns 2 public projects for a user' do
      user  = UserFactory.create_new 1
      user2 = UserFactory.create_new 2
      project = ProjectFactory.create_new user
      project.public = true
      project.name = 'bbb'
      project.parent_id = nil
      project.save
      project2 = ProjectFactory.create_new user2
      project2.public = true
      project2.name = "aaa"
      project2.parent_id = nil
      expect( project2.save ).to be_truthy
      projects = ProjectService.index(user, {:scope => 'all_public'}, 'name')
      expect( projects.count ).to eq(2)
      expect( projects.first.name ).to eq('aaa')
    end
    it 'returns public projects for a user filtered by language' do
      user  = UserFactory.create_new 1
      user2 = UserFactory.create_new 2
      project = ProjectFactory.create_new user
      project.public = true
      project.language = 'Ruby'
      project.parent_id = nil
      project.save
      project2 = ProjectFactory.create_new user2
      project2.public = true
      project2.language = 'Java'
      project2.parent_id = nil
      expect( project2.save ).to be_truthy
      projects = ProjectService.index(user, {:scope => 'all_public', :language => 'Java'})
      expect( projects.count ).to eq(1)
      expect( projects.first.language ).to eq('Java')
    end
    it 'returns empty list for a user filtered by language' do
      user  = UserFactory.create_new 1
      user2 = UserFactory.create_new 2
      project = ProjectFactory.create_new user
      project.public = true
      project.language = 'Ruby'
      project.parent_id = nil
      project.save
      project2 = ProjectFactory.create_new user2
      project2.public = true
      project2.language = 'Java'
      project2.parent_id = nil
      expect( project2.save ).to be_truthy
      projects = ProjectService.index(user, {:scope => 'user', :language => 'Java'})
      expect( projects.count ).to eq(0)
    end
    it 'returns public projects for a user filtered by name' do
      user  = UserFactory.create_new 1
      user2 = UserFactory.create_new 2
      project = ProjectFactory.create_new user
      project.public = true
      project.name = 'hansi_binsi'
      project.language = 'Ruby'
      project.parent_id = nil
      project.save
      project2 = ProjectFactory.create_new user2
      project2.public = true
      project2.language = 'Java'
      project2.parent_id = nil
      expect( project2.save ).to be_truthy
      projects = ProjectService.index(user, {:scope => 'all_public', :name => project.name}, 'license_violations')
      expect( projects.count ).to eq(1)
      expect( projects.first.language ).to eq('Ruby')
      expect( projects.first.name ).to eq(project.name)
    end
  end


  describe "all_projects" do
    it 'returns all projects for the user' do
      user = UserFactory.create_new

      orga1 = Organisation.new(:name => 'orga1')
      expect( orga1.save ).to be_truthy

      orga2 = Organisation.new(:name => 'orga2')
      expect( orga2.save ).to be_truthy

      orga3 = Organisation.new(:name => 'orga3')
      expect( orga3.save ).to be_truthy

      orga1_team1 = Team.new(:name => 'team1', :organisation_id => orga1.ids)
      expect( orga1_team1.save ).to be_truthy
      expect( orga1_team1.add_member(user) ).to be_truthy
      expect( OrganisationService.index( user ).count ).to eq(1)

      orga1_project = ProjectFactory.create_new user
      orga1_project.user_id = nil
      orga1_project.organisation_id = orga1.ids
      orga1_project.team_ids = [orga1_team1.ids]
      expect( orga1_project.save ).to be_truthy

      expect( ProjectService.all_projects(user).keys.count ).to eq(2)
      expect( ProjectService.all_projects(user).keys[0] ).to eq(user.fullname)
      expect( ProjectService.all_projects(user).keys[1] ).to eq("#{orga1.name}/#{orga1_team1.name}")

      orga1_team2 = Team.new(:name => 'team2', :organisation_id => orga1.ids)
      expect( orga1_team2.save ).to be_truthy
      expect( orga1_team2.add_member(user) ).to be_truthy

      orga1_project2 = ProjectFactory.create_new user
      orga1_project2.user_id = nil
      orga1_project2.organisation_id = orga1.ids
      orga1_project2.team_ids = [orga1_team2.ids]
      expect( orga1_project2.save ).to be_truthy

      expect( ProjectService.all_projects(user).keys.count ).to eq(3)
      expect( ProjectService.all_projects(user).keys[0] ).to eq(user.fullname)
      expect( ProjectService.all_projects(user).keys[2] ).to eq("#{orga1.name}/#{orga1_team2.name}")

      orga1_team3 = Team.new(:name => 'team3', :organisation_id => orga1.ids)
      expect( orga1_team3.save ).to be_truthy

      orga1_project3 = ProjectFactory.create_new user
      orga1_project3.user_id = nil
      orga1_project3.organisation_id = orga1.ids
      orga1_project3.team_ids = [orga1_team2.ids]
      expect( orga1_project3.save ).to be_truthy

      # still 3, because user is not part of the new team!
      expect( ProjectService.all_projects(user).keys.count ).to eq(3)

      orga2_team1 = Team.new(:name => 'team1', :organisation_id => orga2.ids)
      expect( orga2_team1.save ).to be_truthy
      expect( orga2_team1.add_member(user) ).to be_truthy

      orga2_project1 = ProjectFactory.create_new user
      orga2_project1.user_id = nil
      orga2_project1.organisation_id = orga2.ids
      orga2_project1.team_ids = [orga2_team1.ids]
      expect( orga2_project1.save ).to be_truthy

      expect( ProjectService.all_projects(user).keys.count ).to eq(4)
      expect( ProjectService.all_projects(user).keys[3] ).to eq("#{orga2.name}/#{orga2_team1.name}")
    end
  end


  describe "corresponding_file" do
    it "returns nil for pom.xml" do
      described_class.corresponding_file('pom.xml').should be_nil
    end
    it "returns Gemfile.lock" do
      described_class.corresponding_file('Gemfile').should eq('Gemfile.lock')
    end
    it "returns composer.lock" do
      described_class.corresponding_file('composer.json').should eq('composer.lock')
    end
    it "returns Podfile.lock" do
      described_class.corresponding_file('Podfile').should eq('Podfile.lock')
    end
  end

  describe "remove_temp_projects" do
    it 'removes all temp projects' do
      user = UserFactory.create_new
      project = ProjectFactory.create_new user
      project.save
      project2 = ProjectFactory.create_new user
      project2.temp = true
      project2.save
      expect( Project.count ).to eq(2)
      ProjectService.remove_temp_projects
      expect( Project.count ).to eq(1)
    end
  end

  describe "type_by_filename" do
    it "returns RubyGems. OK" do
      url1 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_Gemfile?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      url2 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_Gemfile.lock?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      described_class.type_by_filename(url1).should eql(Project::A_TYPE_RUBYGEMS)
      described_class.type_by_filename(url2).should eql(Project::A_TYPE_RUBYGEMS)
      described_class.type_by_filename("Gemfile").should eql(Project::A_TYPE_RUBYGEMS)
      described_class.type_by_filename("Gemfile.lock").should eql(Project::A_TYPE_RUBYGEMS)
      described_class.type_by_filename("app/Gemfile").should eql(Project::A_TYPE_RUBYGEMS)
      described_class.type_by_filename("app/Gemfile.lock").should eql(Project::A_TYPE_RUBYGEMS)
    end
    it "returns nil for wrong Gemfiles. OK" do
      described_class.type_by_filename("Gemfile/").should be_nil
      described_class.type_by_filename("Gemfile.lock/a").should be_nil
      described_class.type_by_filename("app/Gemfile/new.html").should be_nil
      described_class.type_by_filename("app/Gemfile.lock/new").should be_nil
    end
    it "returns nil for wrong CMakeLists.txt. OK" do
      described_class.type_by_filename("CMakeLists.txt").should be_nil
    end

    it "returns Composer. OK" do
      url1 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_composer.json?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      described_class.type_by_filename(url1).should eql(Project::A_TYPE_COMPOSER)
      described_class.type_by_filename(url1).should eql(Project::A_TYPE_COMPOSER)
      described_class.type_by_filename("composer.json").should eql(Project::A_TYPE_COMPOSER)
      described_class.type_by_filename("composer.lock").should eql(Project::A_TYPE_COMPOSER)
      described_class.type_by_filename("app/composer.json").should eql(Project::A_TYPE_COMPOSER)
      described_class.type_by_filename("app/composer.lock").should eql(Project::A_TYPE_COMPOSER)
    end
    it "returns nil for wrong composer. OK" do
      described_class.type_by_filename("composer.json/").should be_nil
      described_class.type_by_filename("composer.lock/a").should be_nil
      described_class.type_by_filename("app/composer.json/new.html").should be_nil
      described_class.type_by_filename("app/composer.lock/new").should be_nil
    end

    it "returns PIP. OK" do
      url1 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_requirements.txt?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      described_class.type_by_filename(url1).should eql(Project::A_TYPE_PIP)
      described_class.type_by_filename("requirements.txt").should eql(Project::A_TYPE_PIP)
      described_class.type_by_filename("app/requirements.txt").should eql(Project::A_TYPE_PIP)
    end
    it "returns nil for wrong pip file" do
      described_class.type_by_filename("requirements.txta").should be_nil
      described_class.type_by_filename("app/requirements.txt/new").should be_nil
    end

    it "returns NPM. OK" do
      url1 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_package.json?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      described_class.type_by_filename(url1).should eql(Project::A_TYPE_NPM)
      described_class.type_by_filename("package.json").should eql(Project::A_TYPE_NPM)
      described_class.type_by_filename("app/package.json").should eql(Project::A_TYPE_NPM)
    end
    it "returns nil for wrong npm file" do
      described_class.type_by_filename("package.jsona").should be_nil
      described_class.type_by_filename("app/package.json/new").should be_nil
    end

    it "returns Gradle. OK" do
      url1 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_dep.gradle?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      described_class.type_by_filename(url1).should eql(Project::A_TYPE_GRADLE)
      described_class.type_by_filename("dependencies.gradle").should eql(Project::A_TYPE_GRADLE)
      described_class.type_by_filename("app/dependencies.gradle").should eql(Project::A_TYPE_GRADLE)
      described_class.type_by_filename("app/deps.gradle").should eql(Project::A_TYPE_GRADLE)
    end
    it "returns nil for wrong gradle file" do
      described_class.type_by_filename("dependencies.gradlea").should be_nil
      described_class.type_by_filename("dep.gradleo1").should be_nil
      described_class.type_by_filename("app/dependencies.gradle/new").should be_nil
      described_class.type_by_filename("app/dep.gradle/new").should be_nil
    end

    it "returns Maven2. OK" do
      url1 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_pom.xml?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      described_class.type_by_filename(url1).should          eql(Project::A_TYPE_MAVEN2)
      described_class.type_by_filename("app/pom.xml").should eql(Project::A_TYPE_MAVEN2)
    end
    it "returns nil for wrong maven2 file" do
      described_class.type_by_filename("pom.xmla").should be_nil
      described_class.type_by_filename("app/pom.xml/new").should be_nil
    end

    it "returns Lein. OK" do
      url1 = "http://localhost:4567/veye_dev_projects/i5lSWS951IxJjU1rurMg_project.clj?AWSAccessKeyId=123&Expires=1360525084&Signature=HRPsn%2Bai%2BoSjm8zqwZFRtzxJvvE%3D"
      described_class.type_by_filename(url1).should eql(Project::A_TYPE_LEIN)
      described_class.type_by_filename("project.clj").should eql(Project::A_TYPE_LEIN)
      described_class.type_by_filename("app/project.clj").should eql(Project::A_TYPE_LEIN)
    end
    it "returns nil for wrong Lein file" do
      described_class.type_by_filename("project.clja").should be_nil
      described_class.type_by_filename("app/project.clj/new").should be_nil
    end

  end


  describe "find" do
    it "returns the project with dependencies" do
      rc_1 = '200.0.0-RC1'
      zz_1 = '0.0.1'

      user    = UserFactory.create_new
      project = ProjectFactory.create_new user

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_2.versions = []
      prod_2.add_version rc_1
      prod_2.version = rc_1
      prod_2.save
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1000.0.0'}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true, {:version_requested => zz_1, :version_current => rc_1}
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, true, {:version_requested => '0.0.0'}

      project.dependencies.count.should eq(3)
      project.dependencies.each do |dep|
        dep.outdated = nil
        dep.release = nil
        dep.save
      end

      project.dependencies.each do |dep|
        dep.outdated.should be_nil
        dep.release.should be_nil
      end

      proj = ProjectService.find project.id.to_s
      proj.dependencies.count.should eq(3)
      proj.dependencies.each do |dep|
        dep.outdated.should be_nil
        dep.release.should be_nil
      end
    end
  end

  describe 'find_child' do
    it "returns the child project with dependencies" do
      rc_1 = '200.0.0-RC1'
      zz_1 = '0.0.1'

      user     = UserFactory.create_new
      project1 = ProjectFactory.create_new user
      project2 = ProjectFactory.create_new user
      project2.parent_id = project1.id.to_s
      project2.save

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_2.versions = []
      prod_2.add_version rc_1
      prod_2.version = rc_1
      prod_2.save
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project2, prod_1, true, {:version_requested => '1000.0.0'}
      dep_2 = ProjectdependencyFactory.create_new project2, prod_2, true, {:version_requested => zz_1, :version_current => rc_1}
      dep_3 = ProjectdependencyFactory.create_new project2, prod_3, true, {:version_requested => '0.0.0'}

      project2.dependencies.count.should eq(3)
      project2.dependencies.each do |dep|
        dep.outdated = nil
        dep.release = nil
        dep.save
      end

      project2.dependencies.each do |dep|
        dep.outdated.should be_nil
        dep.release.should be_nil
      end

      proj = ProjectService.find_child project1.id.to_s, project2.id.to_s
      proj.should_not be_nil
      proj.id.to_s.should eq(project2.id.to_s)
      proj.dependencies.count.should eq(3)
      proj.dependencies.each do |dep|
        dep.outdated.should be_nil
        dep.release.should be_nil
      end
    end
  end


  describe 'store' do

    it 'stores a project' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, false

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, false, {:version_requested => '1.0.0'}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, false, {:version_requested => '0.1.0'}
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, false, {:version_requested => '0.0.0'}

      Product.count.should == 3
      Project.count.should == 0
      Projectdependency.count.should == 0

      resp =described_class.store project
      resp.should be_truthy

      Product.count.should == 3
      Project.count.should == 1
      Projectdependency.count.should == 3
    end

  end



  describe 'summary' do

    it 'returns the summary object' do
      user     = UserFactory.create_new
      project  = ProjectFactory.create_new user
      project2 = ProjectFactory.create_new user
      project2.parent_id = project.ids
      project2.save

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project2, prod_1, true
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, true, {:version_requested => '0.0.0'}

      LicenseWhitelistService.create user, 'SuperList'
      LicenseWhitelistService.add user, 'SuperList', 'MIT'
      LicenseFactory.create_new prod_2, 'GPL'

      expect( LicenseWhitelist.count ).to eq(1)
      project.license_whitelist_id = LicenseWhitelist.first.ids
      expect( project.save ).to be_truthy

      add_sv prod_1

      ProjectUpdateService.update project

      summary = described_class.summary project.ids
      expect( summary ).to_not be_nil

      expect( summary[project.ids][:out_number] ).to eq(1)
      expect( summary[project.ids][:out_number_sum] ).to eq(1)
      expect( summary[project.ids][:sv_count_sum] ).to eq(1)
      expect( summary[project.ids][:sv_count] ).to eq(0)

      expect( summary[project.ids][:licenses_red] ).to eq(1)
      expect( summary[project.ids][:licenses_red_sum] ).to eq(1)

      expect( summary[project.ids][:dependencies] ).to_not be_empty
      expect( summary[project.ids][:dependencies].count ).to eq(1)
      expect( summary[project.ids][:licenses] ).to_not be_empty
      expect( summary[project.ids][:licenses].count ).to eq(2) # 1 red license and 1 unknown.

      expect( summary[project2.ids][:sv_count_sum] ).to eq(1)
      expect( summary[project2.ids][:sv_count] ).to eq(1)
      expect( summary[project2.ids][:sv] ).to_not be_empty
    end

  end
  def add_sv product
    sv = SecurityVulnerability.new({:language => product.language, :prod_key => product.prod_key, :summary => 'test'})
    sv.affected_versions << product.version
    sv.save
    version = product.version_by_number product.version
    version.sv_ids << sv.ids
    version.save
  end



  describe 'ensure_unique_ga' do
    it 'returns true because its turned off' do
      Settings.instance.projects_unique_ga = false
      ProjectService.ensure_unique_ga(nil).should be_truthy
    end
    it 'returns true because there is no other project in db!' do
      Settings.instance.projects_unique_ga = true
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, false
      project.group_id = "org.junit"
      project.artifact_id = 'junit'
      ProjectService.ensure_unique_ga(project).should be_truthy
      Settings.instance.projects_unique_ga = false
    end
    it 'returns true because there is no other project in db!' do
      Settings.instance.projects_unique_ga = true
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, false
      project.group_id = "org.junit"
      project.artifact_id = 'junit'
      project.save
      expect { ProjectService.ensure_unique_ga(project) }.to raise_exception
      Settings.instance.projects_unique_ga = false
    end
  end


  describe 'ensure_unique_gav' do
    it 'returns true because its turned off' do
      Settings.instance.projects_unique_gav = false
      ProjectService.ensure_unique_gav(nil).should be_truthy
    end
    it 'returns true because there is no other project in db!' do
      Settings.instance.projects_unique_gav = true
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, false
      project.group_id = "org.junit"
      project.artifact_id = 'junit'
      project.version = '1.0'
      expect( ProjectService.ensure_unique_gav(project) ).to be_truthy
      Settings.instance.projects_unique_gav = false
    end
    it 'returns true because there is no other project in db!' do
      Settings.instance.projects_unique_gav = true
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, false
      project.group_id = "org.junit"
      project.artifact_id = 'junit'
      project.version = '1.0'
      expect( project.save ).to be_truthy
      expect { ProjectService.ensure_unique_gav(project) }.to raise_exception
      Settings.instance.projects_unique_gav = false
    end
  end


  describe 'ensure_unique_scm' do
    it 'returns true because its turned off' do
      Settings.instance.projects_unique_scm = false
      ProjectService.ensure_unique_scm(nil).should be_truthy
    end
    it 'returns true because there is no other project in db!' do
      Settings.instance.projects_unique_scm = true
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, false
      project.source = "github"
      project.scm_fullname = 'reiz/boom'
      project.scm_branch = 'master'
      project.s3_filename = 'pom.xml'
      ProjectService.ensure_unique_scm(project).should be_truthy
      Settings.instance.projects_unique_scm = false
    end
    it 'returns true because there is no other project in db!' do
      Settings.instance.projects_unique_scm = true
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, false
      project.source = "github"
      project.scm_fullname = 'reiz/boom'
      project.scm_branch = 'master'
      project.s3_filename = 'pom.xml'
      project.save
      expect { ProjectService.ensure_unique_scm(project) }.to raise_exception
      Settings.instance.projects_unique_scm = false
    end
  end


  describe 'destroy_single' do

    it 'destroys a single project' do
      owner   = UserFactory.create_new 1023
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true, {:version_requested => '0.1.0'}
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, true, {:version_requested => '0.0.0'}

      Product.count.should == 3
      Project.count.should == 1
      Projectdependency.count.should == 3

      ProjectService.destroy_single project.id

      Product.count.should == 3
      Project.count.should == 0
      Projectdependency.count.should == 0
    end

  end


  describe 'destroy' do

    it 'destroys a parent project with all childs' do
      owner   = UserFactory.create_new 1023
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true
      child   = ProjectFactory.create_new user, nil, true
      child.parent_id = project.id.to_s
      child.save

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true, {:version_requested => '0.1.0'}
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, true, {:version_requested => '0.0.0'}

      dep_4 = ProjectdependencyFactory.create_new child, prod_1, true, {:version_requested => '1.0.0'}

      Product.count.should == 3
      Project.count.should == 2
      Projectdependency.count.should == 4

      ProjectService.destroy project

      Product.count.should == 3
      Project.count.should == 0
      Projectdependency.count.should == 0
    end

  end


  describe 'destroy_by' do

    it 'destroys a project' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true
      project.user_id = user.ids
      expect( project.save ).to be_truthy
      expect( project.user_id.to_s.eql?(user.ids) ).to be_truthy

      prod_1 = ProductFactory.create_new 1
      dep_1  = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}

      expect( Project.count ).to eq(1)
      ProjectService.destroy_by( user, project.ids )
      expect( Project.count ).to eq(0)
    end

    it 'throws exeception because user has no right to delete project.' do
      dude    = UserFactory.create_new 23
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}

      Project.count.should == 1
      expect { ProjectService.destroy_by(dude, project) }.to raise_exception
      Project.count.should == 1
    end

    it 'throws exeception because user has no right to delete project.' do
      admin   = UserFactory.create_new 23
      admin.admin = true
      admin.save
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}

      Project.count.should == 1
      ProjectService.destroy_by(admin, project)
      Project.count.should == 0
    end

  end


  describe 'merge_by_ga' do

    it 'merges by group and artifact id' do
      user    = UserFactory.create_new

      project = ProjectFactory.create_new user, nil, true
      project.group_id = 'com.company'
      project.artifact_id = 'project_a'
      project.save
      prod_1  = ProductFactory.create_new 1
      dep_1   = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}

      project2 = ProjectFactory.create_new user, nil, true
      dep_1    = ProjectdependencyFactory.create_new project2, prod_1, true, {:version_requested => '1.0.0'}

      Project.where(:parent_id.ne => nil).count.should eq(0)

      response = ProjectService.merge_by_ga project.group_id, project.artifact_id, project2.id, user.id
      response.should be_truthy

      Project.where(:parent_id.ne => nil).count.should eq(1)

      project2 = Project.find project2.id.to_s
      project2.parent_id.should_not be_empty
      project2.parent_id.to_s.should eq( project.id.to_s )
    end

  end


  describe 'merge' do

    it 'merges' do
      user    = UserFactory.create_new

      project = ProjectFactory.create_new user, nil, true
      prod_1  = ProductFactory.create_new 1
      dep_1   = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}

      project2 = ProjectFactory.create_new user, nil, true
      dep_1    = ProjectdependencyFactory.create_new project2, prod_1, true, {:version_requested => '1.0.0'}

      Project.where(:parent_id.ne => nil).count.should eq(0)

      response = ProjectService.merge project.id, project2.id, user.id
      response.should be_truthy

      Project.where(:parent_id.ne => nil).count.should eq(1)

      project2 = Project.find project2.id.to_s
      project2.parent_id.should_not be_empty
      project2.parent_id.to_s.should eq( project.id.to_s )
    end

  end


  describe 'unmerge' do

    it 'unmerges' do
      user    = UserFactory.create_new

      project = ProjectFactory.create_new user, nil, true
      prod_1  = ProductFactory.create_new 1
      dep_1   = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}

      project2 = ProjectFactory.create_new user, nil, true
      dep_1    = ProjectdependencyFactory.create_new project2, prod_1, true, {:version_requested => '1.0.0'}

      project2.parent_id = project.id
      project2.save

      response = ProjectService.unmerge project.id, project2.id, user.id
      response.should be_truthy

      Project.where(:parent_id.ne => nil).count.should eq(0)
    end

    it 'throws exception because user is not a collaborator' do
      user    = UserFactory.create_new 1, true
      hacker  = UserFactory.create_new 2, true

      project = ProjectFactory.create_new user, nil, true
      prod_1  = ProductFactory.create_new 1
      dep_1   = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1.0.0'}

      project2 = ProjectFactory.create_new user, nil, true
      dep_1    = ProjectdependencyFactory.create_new project2, prod_1, true, {:version_requested => '1.0.0'}

      project2.parent_id = project.id
      project2.save

      expect { ProjectService.unmerge(project.id, project2.id, hacker.id) }.to raise_exception
    end

  end


  describe 'user_product_index_map' do

    it 'returns an empty hash because user has no projects' do
      user = UserFactory.create_new
      map = ProjectService.user_product_index_map user
      map.empty?().should be_truthy
    end

    it 'returns an empty hash because user has no projects' do
      user = UserFactory.create_new

      project_1 = ProjectFactory.create_new user, nil, true
      project_2 = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project_1, prod_1, true, {:version_requested => '1.0.0'}
      dep_2 = ProjectdependencyFactory.create_new project_2, prod_2, true, {:version_requested => '0.1.0'}
      dep_3 = ProjectdependencyFactory.create_new project_2, prod_3, true, {:version_requested => '0.0.0'}
      dep_4 = ProjectdependencyFactory.create_new project_2, prod_1, true, {:version_requested => '0.0.0'}

      map = ProjectService.user_product_index_map user
      map.empty?().should be_falsey
      map.count.should == 3

      key = "#{prod_1.language_esc}_#{prod_1.prod_key}"
      map[key].count.should == 2

      key = "#{prod_2.language_esc}_#{prod_2.prod_key}"
      map[key].count.should == 1
    end

  end


  describe 'outdated_dependencies' do

    it 'returns the outdated_dependencies' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1000000.0.0'}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true, {:version_requested => '0.0.0'}
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, true, {:version_requested => '0.0.0'}

      outdated_deps = ProjectService.outdated_dependencies project
      outdated_deps.should_not be_nil
      outdated_deps.count.should == 2
    end

  end


  describe 'unknown_licenses' do

    it 'returns an empty list' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true
      unknown = described_class.unknown_licenses( project )
      unknown.should be_empty
    end
    it 'returns an empty list' do
      unknown = described_class.unknown_licenses( nil )
      unknown.should be_empty
    end
    it 'returns a list with 1 element, because the according product doesnt has a license' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => '1000000.0.0'}

      unknown = described_class.unknown_licenses( project )
      unknown.should_not be_empty
      unknown.size.should eq(1)
      unknown.first.name.should eq(prod_1.name)
    end
    it 'returns a list with 1 element, because the according product is unknown.' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      dep_1 = ProjectdependencyFactory.create_new project, nil, true, {:version_requested => '1000000.0.0'}

      unknown = described_class.unknown_licenses( project )
      unknown.should_not be_empty
      unknown.size.should eq(1)
      unknown.first.id.should eq(dep_1.id)
    end
    it 'returns a list with 1 element' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      liz_1 = LicenseFactory.create_new prod_1, 'MIT'
      liz_2 = LicenseFactory.create_new prod_2, 'MIT'

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true, {:version_requested => prod_2.version}
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, true, {:version_requested => prod_3.version}

      unknown = described_class.unknown_licenses( project )
      unknown.should_not be_empty
      unknown.size.should eq(1)
      unknown.first.id.should eq(dep_3.id)
    end
    it 'returns a list with 2 elements. One requested version of the product has no license.' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3

      liz_1 = LicenseFactory.create_new prod_1, 'MIT'
      liz_2 = LicenseFactory.create_new prod_2, 'MIT'

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true, {:version_requested => '0.0.NA'}
      dep_3 = ProjectdependencyFactory.create_new project, prod_3, true, {:version_requested => prod_3.version}

      unknown = described_class.unknown_licenses( project )
      unknown.should_not be_empty
      unknown.size.should eq(2)
    end

  end


  describe 'red_licenses' do

    it 'returns an empty list because project is nil' do
      red = ProjectService.red_licenses nil
      red.should be_empty
    end
    it 'returns an empty list because project dependencies is empty' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true
      red = ProjectService.red_licenses project
      red.should be_empty
    end
    it 'returns an empty list because project has no whitelist assigned.' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1  = ProductFactory.create_new 1
      liz_1 = LicenseFactory.create_new prod_1, 'MIT'
      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => prod_1.version}

      red = ProjectService.red_licenses project
      red.should be_empty
    end
    it 'returns an empty list because Projectdependency is on whitelist' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1 = ProductFactory.create_new 1
      liz_1  = LicenseFactory.create_new prod_1, 'MIT'
      dep_1  = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => prod_1.version}
      whitelist = LicenseWhitelistFactory.create_new 'OSS', ['MiT']
      whitelist.save
      project.license_whitelist_id = whitelist.id
      project.save

      red = ProjectService.red_licenses project
      red.should be_empty
    end
    it 'returns a list with 1 element' do
      user    = UserFactory.create_new
      project = ProjectFactory.create_new user, nil, true

      prod_1 = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2

      liz_1  = LicenseFactory.create_new prod_1, 'MIT'
      liz_2 = LicenseFactory.create_new prod_2, 'BSD'

      dep_1 = ProjectdependencyFactory.create_new project, prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project, prod_2, true, {:version_requested => prod_2.version}

      whitelist = LicenseWhitelistFactory.create_new 'OSS', ['MiT']
      whitelist.save
      project.license_whitelist_id = whitelist.id
      project.save

      ProjectdependencyService.update_licenses project

      red = ProjectService.red_licenses project
      expect( red ).to_not be_empty
      expect( red.count ).to eq(1)
      expect( red.first.name ).to eq(dep_2.name)
    end

  end


  describe 'update_sums' do

    it 'updates the sums for a single project' do
      project = Project.new({ :dep_number => 5, :out_number => 1,
        :unknown_number => 2, :licenses_red => 2, :licenses_unknown => 2 })

      project.dep_number_sum.should eq(0)
      project.out_number_sum.should eq(0)
      project.unknown_number_sum.should eq(0)
      project.licenses_red_sum.should eq(0)
      project.licenses_unknown_sum.should eq(0)

      ProjectService.update_sums( project )

      project.dep_number_sum.should eq( project.dep_number )
      project.out_number_sum.should eq( project.out_number )
      project.unknown_number_sum.should eq( project.unknown_number )
      project.licenses_red_sum.should eq( project.licenses_red )
      project.licenses_unknown_sum.should eq( project.licenses_unknown )
    end

    it 'updates the sums for a project with a child' do

      user     = UserFactory.create_new
      project  = ProjectFactory.create_new user, {:name => 'project_1'}, true
      project2 = ProjectFactory.create_new user, {:name => 'project_2'}, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3
      prod_4  = ProductFactory.create_new 4

      mit = LicenseFactory.create_new prod_1, 'MIT'
      gpl = LicenseFactory.create_new prod_2, 'GPL'

      dep_1 = ProjectdependencyFactory.create_new project , prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project , prod_2, true, {:version_requested => prod_2.version}
      dep_3 = ProjectdependencyFactory.create_new project2, prod_3, true, {:version_requested => '0.0.0'}
      dep_4 = ProjectdependencyFactory.create_new project2, prod_4, true, {:version_requested => '0.0.0'}
      dep_5 = ProjectdependencyFactory.create_new project2, prod_1, true, {:version_requested => prod_1.version}
      dep_6 = ProjectdependencyFactory.create_new project2, nil, true

      ProjectdependencyService.update_outdated!( dep_1 )
      ProjectdependencyService.update_outdated!( dep_2 )
      ProjectdependencyService.update_outdated!( dep_3 )
      ProjectdependencyService.update_outdated!( dep_4 )
      ProjectdependencyService.update_outdated!( dep_5 )

      whitelist = LicenseWhitelistFactory.create_new 'OSS', ['MIT']
      expect( whitelist.save ).to be_truthy

      project.license_whitelist_id = whitelist.id
      expect( project.save ).to be_truthy

      ProjectService.update_license_numbers! project
      expect( project.licenses_red ).to eq(1)
      expect( project.licenses_red_sum ).to eq(0)
      expect( project.licenses_unknown ).to eq(0)

      project2.parent_id = project.id.to_s
      project2.license_whitelist_id = whitelist.id
      expect( project2.save ).to be_truthy
      ProjectService.update_license_numbers! project2
      expect( project2.licenses_red ).to eq(0)
      expect( project2.licenses_unknown ).to eq(3)

      ProjectService.update_sums( project )
      project.licenses_red_sum.should eq( 1 )
      project.licenses_unknown_sum.should eq( 3 )

      project.dep_number_sum.should eq( 5 )
      project.out_number_sum.should eq( 2 )
      project.unknown_number_sum.should eq( 1 )
    end

    it 'updates the sums for a project with a child' do

      user     = UserFactory.create_new
      project  = ProjectFactory.create_new user, {:name => 'project_1'}, true
      project2 = ProjectFactory.create_new user, {:name => 'project_2'}, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2
      prod_3  = ProductFactory.create_new 3
      prod_4  = ProductFactory.create_new 4

      mit = LicenseFactory.create_new prod_3, 'MIT'
      gpl = LicenseFactory.create_new prod_3, 'GPL'
      expect( License.count ).to eq(2)

      dep_1 = ProjectdependencyFactory.create_new project , prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project , prod_2, true, {:version_requested => prod_2.version}
      dep_3 = ProjectdependencyFactory.create_new project2, prod_3, true, {:version_requested => prod_3.version}
      dep_4 = ProjectdependencyFactory.create_new project2, prod_4, true, {:version_requested => '0.0.0'}
      dep_5 = ProjectdependencyFactory.create_new project2, prod_1, true, {:version_requested => prod_1.version}
      dep_6 = ProjectdependencyFactory.create_new project2, nil, true

      ProjectdependencyService.update_outdated!( dep_1 )
      ProjectdependencyService.update_outdated!( dep_2 )
      ProjectdependencyService.update_outdated!( dep_3 )
      ProjectdependencyService.update_outdated!( dep_4 )
      ProjectdependencyService.update_outdated!( dep_5 )

      whitelist = LicenseWhitelistFactory.create_new 'OSS', ['MIT']
      whitelist.pessimistic_mode = true
      expect( whitelist.save ).to be_truthy

      project.license_whitelist_id = whitelist.id
      expect( project.save ).to be_truthy

      ProjectService.update_license_numbers! project
      expect( project.licenses_red ).to eq(0)
      expect( project.licenses_red_sum ).to eq(0)
      expect( project.licenses_unknown ).to eq(2)

      project2.parent_id = project.ids
      project2.license_whitelist_id = whitelist.id
      expect( project2.save ).to be_truthy
      ProjectService.update_license_numbers! project2
      expect( project2.licenses_red ).to eq(1)
      expect( project2.licenses_unknown ).to eq(3)

      ProjectService.update_sums( project )
      project.licenses_red_sum.should eq( 1 )
      project.licenses_unknown_sum.should eq( 4 )
    end

    it 'updates the sums for a project with a child and no LWL' do
      user     = UserFactory.create_new
      project1 = ProjectFactory.create_new user, {:name => 'project_1'}, true
      project2 = ProjectFactory.create_new user, {:name => 'project_2'}, true
      project2.parent_id = project1.ids
      expect( project2.save ).to be_truthy

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2

      mit = LicenseFactory.create_new prod_2, 'MIT'
      expect( License.count ).to eq(1)

      dep_1 = ProjectdependencyFactory.create_new project1 , prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project2 , prod_2, true, {:version_requested => prod_2.version}

      ProjectdependencyService.update_outdated!( dep_1 )
      ProjectdependencyService.update_outdated!( dep_2 )

      ProjectService.update_license_numbers! project1
      ProjectService.update_license_numbers! project2

      ProjectService.update_sums project1

      # Must be 0 because there is no license whitelist.
      expect( project1.licenses_red ).to eq(0)
      expect( project1.licenses_red_sum ).to eq(0)
    end

    it 'updates the sums for a project with LWL' do
      user     = UserFactory.create_new
      project1 = ProjectFactory.create_new user, {:name => 'project_1'}, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2

      mit = LicenseFactory.create_new prod_2, 'MIT'
      mit = LicenseFactory.create_new prod_2, 'GPL'
      expect( License.count ).to eq(2)

      dep_1 = ProjectdependencyFactory.create_new project1 , prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project1 , prod_2, true, {:version_requested => prod_2.version}

      whitelist = LicenseWhitelistFactory.create_new 'OSS', ['MIT']
      expect( whitelist.save ).to be_truthy

      project1.license_whitelist_id = whitelist.id
      expect( project1.save ).to be_truthy

      ProjectdependencyService.update_outdated!( dep_1 )
      ProjectdependencyService.update_outdated!( dep_2 )

      ProjectService.update_license_numbers! project1

      ProjectService.update_sums project1

      # Must be 0 because there is no license whitelist.
      expect( project1.licenses_red ).to eq(0)
      expect( project1.licenses_red_sum ).to eq(0)
    end

    it 'updates the sums for a project with pessimistic LWL' do
      user     = UserFactory.create_new
      project1 = ProjectFactory.create_new user, {:name => 'project_1'}, true

      prod_1  = ProductFactory.create_new 1
      prod_2  = ProductFactory.create_new 2

      mit = LicenseFactory.create_new prod_2, 'MIT'
      mit = LicenseFactory.create_new prod_2, 'GPL'
      expect( License.count ).to eq(2)

      dep_1 = ProjectdependencyFactory.create_new project1 , prod_1, true, {:version_requested => prod_1.version}
      dep_2 = ProjectdependencyFactory.create_new project1 , prod_2, true, {:version_requested => prod_2.version}

      whitelist = LicenseWhitelistFactory.create_new 'OSS', ['MIT']
      whitelist.pessimistic_mode = true
      expect( whitelist.save ).to be_truthy

      project1.license_whitelist_id = whitelist.id
      expect( project1.save ).to be_truthy

      ProjectdependencyService.update_outdated!( dep_1 )
      ProjectdependencyService.update_outdated!( dep_2 )

      ProjectService.update_license_numbers! project1

      ProjectService.update_sums project1

      # Must be 0 because there is no license whitelist.
      expect( project1.licenses_red ).to eq(1)
      expect( project1.licenses_red_sum ).to eq(1)
    end

  end


end
