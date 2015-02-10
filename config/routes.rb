OpenCongress::Application.routes.draw do

  # API
  constraints :subdomain => 'api' do
    with_options :via => [:get] do |f|
      f.match '/' => redirect(Settings.base_url + 'api')
      f.match '/bill/text_summary/:id' => 'bill#status_text'
      f.match '/roll_call/text_summary/:id' => 'roll_call#summary_text'
      f.match '/:action(/:id)', :controller => 'api'
    end
    with_options :format => [:json, :xml], :via => [:get] do |f|
      f.match '/groups(.:format)' => 'groups#index'
      f.match '/groups(/:id(.:format))' => 'groups#show'
    end
  end

  resources :mailing_list_items
  resources :watch_dogs

  resources :states do
    resources :districts
  end

  resources :groups do
    resources :group_invites
    resources :group_members
    resources :group_bill_positions

    resource :political_notebook do
      resources :notebook_items do
        collection do
          get :feed
        end
      end
      resources :notebook_links
      resources :notebook_videos
      resources :notebook_notes
      resources :notebook_files
    end
  end

  resources :simple_captcha, :only => :show

  scope 'email_congress', :controller => :email_congress do

    with_options :via => [:get] do |f|
      f.match 'postmark/inbound', :action => :message_to_members
      f.match 'confirmed/:confirmation_code', :action => :confirmed
      f.match 'confirm/:confirmation_code', :action => :confirm
      f.match 'confirm', :action => :confirm
    end

    with_options :via => [:post] do |f|
      f.match 'discard/:confirmation_code', :action => :discard
    end

    with_options :via => [:get,:post] do |f|
      f.match 'complete_profile/:confirmation_code', :action => :complete_profile
    end

  end

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  # match ':controller/service.wsdl' => 'wsdl'

  # Handle bill routing. The action determines what information about the bill will
  # be displayed.
  with_options :via => [:get] do |f|
    f.match 'bill/:id/users_tracking' => 'friends#tracking_bill', :as => :users_tracking_bill
    f.match 'bill/:id/users_tracking/:state' => 'friends#tracking_bill', :state => /\w{2}/, :as => :users_tracking_bill_by_state
  end

  scope 'bill', :controller => 'bill' do
    with_options :via => [:get, :post] do |f|

      for action in %w{ all pending popular major hot readthebill compare compare_by_issues atom_top20 }
        f.match action, :action => action, :as => 'bill_' + action
      end
      f.match '/test', :action => 'test'
      f.match 'most/:type', :action => 'most_commentary', :as => :bill_most_commentary
      f.match 'most/viewed', :action => 'popular'
      f.match 'atom/most/viewed', :action => 'atom_top20'
      f.match 'atom/most/:type', :action => 'atom_top_commentary'
      f.match 'atom/list/:chamber', :action => 'atom_list'
      f.match 'type/:bill_type(/:page)', :action => 'list_bill_type'
      f.match 'text/status/:id', :action => 'status_text'
      f.match 'upcoming/:id', :action => 'upcoming'
      f.match 'bill_vote/:bill/:id', :action => 'bill_vote'

      scope ':id' do
        f.match 'blogs(/:page)', :action => 'blogs', :as => :blogs_bill
        f.match 'blogs/search(/:page)', :action => 'commentary_search', :commentary_type => 'blog'
        f.match 'news(/:page)', :action => 'news', :as => :news_bill
        f.match 'news/search(/:page)', :action => 'commentary_search', :commentary_type => 'news'
        f.match 'text', :action => 'text', :as => :bill_text
        f.match 'full_text', :action => 'full_text', :as => :bill_full_text
        f.match 'comments', :action => 'comments', :as => :bill_comments
        f.match 'show', :action => 'show', :as => :bill
        f.match ':action'
      end

      f.match ':id' => 'bill#show'
    end
  end


  match 'bill' => redirect('/bill/all'), :via => [:get]

  scope 'people', :controller => 'people' do
    with_options :via => [:get, :post] do |f|
      f.match 'senators', :action => 'people_list', :person_type => 'senators'
      f.match 'representatives', :action => 'people_list', :person_type => 'representatives'
      f.match ':person_type/most/:type', :action => 'most_commentary'
      f.match ':person_type/atom/most/:type', :action => 'atom_top_commentary'
      f.match 'atom/featured', :action => 'atom_featured'
      f.match 'wiki/:id', :action => 'wiki'
      f.match 'comments/:id', :action => 'comments'
      f.match 'news/:id(/:page)', :action => 'news', :as => :news_person
      f.match 'blogs/:id(/:page)', :action => 'blogs', :as => :blogs_person
      f.match 'votes_with_party/:chamber/:party', :action => 'votes_with_party'
      f.match 'voting_history/:id/:page', :action => 'voting_history', :constraints => { :page => /\d+/ }
      f.match 'compare.:format', :action => 'compare'
      f.match 'show/:id', :action => 'show', :as => 'person'
      f.match 'bills/:id', :action => 'bills', :constraints => { :page => /^\d+/ }
    end
  end

  match 'person/*path' => redirect("/people/%{path}"), :via => [:get]

  namespace :admin do
    resources :wiki_links, :pvs_category_mappings, :talking_points
    resources :articles do
      collection do
        get :list
        get :edit_blogroll
      end
      resources :article_images
    end

    with_options :via => [:get, :post] do |f|

      f.match '/' => 'index#index', :as => 'admin'

      scope 'stats', :controller => 'stats' do
        f.match 'bills.:format', :action => 'bills'
        f.match 'partner_email.:format', :action => 'partner_email'
      end

      f.match 'contact_congress' => 'contact_congress#index'
      f.match 'contact_congress/letters' => 'contact_congress#letters'

    end
  end

  with_options :via => [:get, :post] do |f|
    f.match 'contact_congress/status/:id' => 'contact_congress_letters#last'

    f.match '/:controller(/:action(/:id))', :controller => /admin\/[^\/]+/

    f.match 'battle_royale' => 'battle_royale#index'
    f.match 'battle_royale/:action', :controller => 'battle_royale'

    f.match 'blog(/:tag)' => 'articles#list', :as => :blogs

    scope 'articles', :controller => 'articles' do
      f.match 'view/:id', :action => 'view', :as => :article
      f.match ':id/atom', :action => 'article_atom'
    end

    # Temporary redirect for DRM's announcement post
    f.match 'about/ppf-askthem' => redirect('/articles/view/2537-Big-News')

    f.match 'issues/most_viewed' => 'issue#most_viewed', :as => :most_viewed_issues
    f.match 'issues/all/(:id)' => 'issue#all', :as => :all_issues
    f.match 'issues' => 'issue#index', :as => :issues

    f.match 'roll_call', :controller => :roll_call, :action => :index
    f.match 'committee', :controller => :committee, :action => :index

    scope 'issues', :controller => 'issue' do
      f.match 'show/:id', :action => 'show', :as => :issue
      f.match ':action/:id'
    end
  end

  scope 'contact_congress_letters', :controller => 'contact_congress_letters' do
    post ':id', :action => :update
  end

  resources :contact_congress_letters, :only => [:index, :show, :new, :update] do
    get 'create_from_formageddon', :on => :collection # create uses POST and we'll be redirecting to create
    get 'get_recipients', :on => :collection
    get 'delayed_send', :on => :collection
    get 'get_replies', :on => :collection
  end

  scope :controller => 'account' do
    with_options :via => [:get, :post] do |f|

      for action in %w{ login why logout signup welcome contact_congress determine_district }
        f.match action, :action => action
      end

      f.match 'register', :action => 'signup'
      f.match 'account/confirm/:login', :action => 'confirm'

    end
  end

  scope :controller => 'comments' do
    with_options :via => [:get, :post] do |f|
      f.match 'comments/all_comments/:object/:id', :action => 'all_comments'
      f.match 'comments/atom/:object/:id', :action => 'atom_comments'
    end
  end

  # /users/:login
  scope 'users/:login' do
    get 'profile' => 'profile#show', :as => :user_profile
    get 'profile/edit' => 'profile#edit', :as => :edit_profile
    patch 'profile' => 'profile#update', :as => :update_profile
    delete 'profile' => 'profile#destroy', :as => :destroy_profile
    delete 'profile/images' => 'profile#delete_images', :as => :delete_profile_images

    # /users/:login/profile
    scope 'profile' do

      resource :political_notebook do
        collection do
          post :update_privacy
          get :feed
        end
        resources :notebook_links do
          collection do
            get :faceform
          end
        end
        resources :notebook_videos
        resources :notebook_notes
        resources :notebook_files
      end

      # /users/:login/profile/friends/:action
      resources :friends
      scope 'friends', :controller => 'friends' do
        with_options :via => [:get, :post] do |f|

          for action in %w{ import_contacts like_voters invite_contacts near_me invite invite_form add search }
            f.match action, :action => action, :as => 'friends_' + action
          end

          for action in %w{ confirm deny } do
            f.match action + '/:id', :action => action, :as => 'friends_add_' + action
          end

        end
      end

      # /users/:login/profile/:action
      scope :controller => 'profile' do
        with_options :via => [:get, :post] do |f|

          for action in %w{ actions items_tracked watchdog edit_profile bills_supported tracked_rss user_actions_rss bills_opposed my_votes bills comments issues committees groups upload_pic
                            disconnect_facebook_account } do
            f.match action, :action => action, :as => 'user_' + action
          end

          f.match ':person_type', :action => 'person'

        end
      end

    end # scope 'profile'

    match 'feeds/:action(/:key)', :controller => 'user_feeds', :via => [:get,:post]

  end # scope 'users/:login'

  get 'users/:login' => redirect {|params, request| Rails.application.routes.url_helpers.user_profile_path(params[:login]) }

  match 'video/rss' => 'video#all', :format => 'atom', :via => [:get,:post]

  with_options :via => [:get, :post] do |f|
    scope :controller => 'roll_call' do
      f.match 'roll_call/text/summary/:id', :action => 'summary_text'
      f.match 'vote/:year/:chamber/:number(/:state)', :action => 'by_number', :year => /\d{4}/, :chamber => /[hs]/, :number => /\d+/, :state => /\w{2}/#, :as => :roll_call
    end

    scope :controller => 'committee' do
      f.match '/committee/by_chamber/:chamber', :action => 'by_chamber'
    end
  end

  post '/subscribe.:format' => 'email_subscriptions#adhoc'

  with_options :via => [:get, :post] do |f|
    f.match 'tools(/:action(/:id))', :controller => 'resources', :as => 'tools'

    f.match '/widgets' => 'widgets#index', :as => 'widgets'
    f.match '/widgets/deprecated' => 'widgets#deprecated', :as => 'deprecated_widgets'
    f.match '/widgets/bill' => 'widgets#bill', :as => 'bill_widget'
    f.match '/widgets/bills' => 'widgets#bills', :as => 'bills_widget'
    f.match '/widgets/people' => 'widgets#people', :as => 'people_widget'
    f.match '/widgets/group' => 'widgets#group', :as => 'group_widget'

    f.match 'api' => 'api#index'
    f.match 'api/bill/text_summary/:id' => 'bill#status_text'
    f.match 'api/roll_call/text_summary/:id' => 'roll_call#summary_text'
    f.match 'api(/:action(/:id)(.:format))', :controller => 'api'

    # Temporary routes for health care legislation
    f.match 'baucus_bill_health_care.html' => 'index#s1796_redirect'
    f.match 'presidents_health_care_proposal' => 'index#presidents_health_care_proposal'
    f.match 'senate_health_care_bill' => 'bill#text', :id => '111-h3590', :version => 'ocas'
    f.match 'house_reconciliation' => 'index#house_reconciliation'
    f.match 'pipa' => 'index#pipa'

    f.match '/donate' => redirect('http://sunlightfoundation.com/about/funding/')
    f.match '/about/privacy_policy' => redirect("/terms")
    f.match '/about/terms_of_service' => redirect("/terms")
    f.match 'terms' => 'about#terms'
    f.match 'howtouse' => 'about#howtouse'
    f.match '/userguide' => redirect("/howtouse")
    f.match '/senate', to: 'chambers#senate'
    f.match '/house', to: 'chambers#house'
  end

  resources :contact, :only => [:index, :create]

  
  match ':controller(/:action(/:id))', :via => [:get,:post,:put,:delete]
  
  #match '*path' => 'index#notfound' #unless Rails.application.config.consider_all_requests_local

  get '/', to: 'styleguide#show', :constraints => { :subdomain => /design/ }
  match '/:action(/:id)', :controller => 'styleguide', :via => [:get], :constraints => { :subdomain => /design/ }

  # root :to => 'index#index', :as => :home
  # Dev homepage
  root :to => 'index#index', :as => :home

end