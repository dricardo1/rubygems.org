require 'test_helper'

class GemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @rubygem = create(:rubygem, name: "sandworm", number: "1.0.0")
  end

  test "gem page with a non valid format" do
    get rubygem_path(@rubygem), nil, {'HTTP_ACCEPT' => 'application/mercurial-0.1'}
    assert page.has_content? "1.0.0"
  end
end