require 'test_helper'

class VersionsControllerTest < ActionController::TestCase
  context 'GET to index' do
    setup do
      @rubygem = FactoryGirl.create(:rubygem)
      @versions = (1..5).map do |version|
        FactoryGirl.create(:version, :rubygem => @rubygem)
      end

      get :index, :rubygem_id => @rubygem.name
    end

    should respond_with :success
    should render_template :index
    should assign_to(:rubygem) { @rubygem }
    should assign_to(:versions) { @rubygem.reload.versions }

    should "show all related versions" do
      @versions.each do |version|
        assert page.has_content?(version.number)
      end
    end
  end

  context "GET to index for gem with no versions" do
    setup do
      @rubygem = FactoryGirl.create(:rubygem)
      get :index, :rubygem_id => @rubygem.name
    end

    should respond_with :success
    should render_template :index
    should "show not hosted notice" do
      assert page.has_content?('This gem is not currently hosted')
    end
  end

  context "On GET to show" do
    setup do
      @latest_version = FactoryGirl.create(:version, :built_at => 1.week.ago, :created_at => 1.day.ago)
      @rubygem = @latest_version.rubygem
      get :show, :rubygem_id => @rubygem.name, :id => @latest_version.number
    end

    should respond_with :success
    should render_template "rubygems/show"
    should assign_to :rubygem
    should assign_to(:latest_version) { @latest_version }
    should "render info about the gem" do
      assert page.has_content?(@rubygem.name)
      assert page.has_content?(@latest_version.number)
    end
  end
end
