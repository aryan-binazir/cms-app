ENV["RACK_ENV"] = "test"

require "fileutils"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
Minitest::Reporters.use!

require_relative "../cms"

class CMSTest < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content="")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def session
    last_request.env["rack.session"]
  end

  def test_home
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document "history.txt", "Yukihiro Matsumoto dreams up Ruby." 

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Yukihiro Matsumoto dreams up Ruby." 
  end

  def test_viewing_non_existent_document
    get "/notafile.ext"

    assert_equal 302, last_response.status
    assert_equal "notafile.ext does not exist.", session[:message]
  end

  def test_markdown_rendering
    create_document 'about.md', '`Ruby is...`'

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby is..."
  end

  def test_editing_document
    create_document 'changes.txt'

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_updating_document
    post "/changes.txt", {content: "new content"}, admin_session

    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_view_create_document
    get '/new/document', {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end
    
  def test_create_new_document
    post '/new/document', {filename: "test.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_includes "test.txt was created", session[:message]
  
    get '/'
    assert_includes last_response.body, "test.txt"
  end

  def test_create_new_document_without_filename
    post "/new/document", {filename: ""}, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_deleting_file
    create_document "test.txt", "some content"

    post '/test.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_includes "test.txt has been deleted.", session[:message]
  
    get '/'
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_view_sign_in_page
    get '/users/signin_page'
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Enter username"
    assert_includes last_response.body, "Enter password"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_wrong_credentials
    post '/users/signin', username: "admin1", password: "qwerty"
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid username or password"
  end

  def test_successful_sign_in
    post '/users/signin', username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome! Log in successful.", session[:message]
    assert_equal "admin", session[:username]
    
    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  def test_signout
    get "/", {}, {"rack.session" => {username: "admin"} }
    assert_includes last_response.body, "Signed in as admin"

    post "users/signout"
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_editing_document_signed_out
    create_document("test.txt")

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document_signed_out
    post "/changes.txt", {content: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_view_new_document_form_signed_out
    get '/new/document'

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_signed_out
    post "/new/document", { filename: "test.txt" }

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_deleting_document_signed_out
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end
end