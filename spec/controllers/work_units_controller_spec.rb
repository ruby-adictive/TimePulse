require 'spec_helper'

describe WorkUnitsController do
  describe "permissions" do
    let! :work_unit do FactoryGirl.create(:work_unit) end
    let! :annotation do FactoryGirl.create(:activity) end

    describe "accessed by guest" do

      it "should not permit GET show" do
        get :show, :id => work_unit.id
        verify_authorization_unsuccessful
      end

      it "should not permit GET new" do
        get :new
        verify_authorization_unsuccessful
      end

      it "should not permit GET edit" do
        get :edit, :id => work_unit.id
        verify_authorization_unsuccessful
      end

      it "should not permit POST create" do
        post :create, :work_unit => work_unit
        verify_authorization_unsuccessful
      end

      it "should not permit PUT update" do
        put :update, :id => work_unit.id
        verify_authorization_unsuccessful
      end

      it "should not permit DELETE destroy" do
        delete :destroy, :id => work_unit.id
        verify_authorization_unsuccessful
      end
    end
  end

  describe "as admin" do
    before(:each) do
      Timecop.return
      @user = authenticate(:admin)
      @work_unit = FactoryGirl.create(:work_unit)
      @local_tz = ActiveSupport::TimeZone["Fiji"]
    end

    let! :project do FactoryGirl.create(:project) end


    ########################################################################################
    #                                      GET SHOW
    ########################################################################################
    describe "responding to GET show" do
      it "should expose the requested work_unit as @work_unit" do
        get :show, :id => @work_unit.id
        assigns[:work_unit].should == @work_unit
      end
    end

    ########################################################################################
    #                                      GET NEW
    ########################################################################################
    describe "responding to GET new" do
      it "should expose a new work_unit as @work_unit" do
        get :new
        assigns[:work_unit].should be_a(WorkUnit)
        assigns[:work_unit].should be_new_record
      end
    end

    ########################################################################################
    #                                      GET EDIT
    ########################################################################################
    describe "responding to GET edit" do
      it "should expose the requested work_unit as @work_unit" do
        get :edit, :id => @work_unit.id
        assigns[:work_unit].should == @work_unit
      end

      it "should store the url in session" do
        get :edit, :id => @work_unit.id
        session[:return_to].should eq "/previous/page"
      end
    end


    ########################################################################################
    #                                      POST CREATE
    ########################################################################################
    describe "responding to POST create" do

      describe "for a work unit without a project" do
        before do
          post :create, :work_unit => {
            :start_time => @local_tz.now.to_s,
            :time_zone => (@local_tz.utc_offset / 3600)
         }
        end

        it "should assign an invalid work unit" do
          assigns[:work_unit].should_not be_valid
        end
      end

      describe "for a work unit without a start time" do
        before do
          post :create, :work_unit => { :project_id => project.id,
            :time_zone => (@local_tz.utc_offset / 3600) }
        end

        it "should assign an invalid work unit" do
          assigns[:work_unit].should_not be_valid
        end
      end

      describe "with stop time before start time" do
        before :each do
          @start = @local_tz.parse("May 6, 2010 4:00").to_s(:date_and_time)
          @stop  = @local_tz.parse("May 5, 2010 4:20").to_s(:date_and_time)
          post :create, :work_unit => {
            :start_time => @start.to_s,
            :stop_time => @stop.to_s,
            :time_zone => (@local_tz.utc_offset / 3600),
            :project_id => project.id }
        end

        it "should assign an invalid work unit" do
          assigns[:work_unit].should_not be_valid
        end

        it "should leave hours empty" do
          assigns[:work_unit].hours.should be_blank
        end
      end

      describe "for a work unit with a start time but blank stop time" do
        before do
          @start = @local_tz.now - 2 * 60 * 60
          @time = @local_tz.now
          post :create, :work_unit => { :project_id => project.id,
            :start_time => @start.to_s(:short_datetime), :time_zone => (@local_tz.utc_offset / 3600), :calculate => true, :hours => '2'
          }
        end

        it "should succeed" do
          response.should be_redirect
        end

        it "should create a work unit with a real stop time" do
          assigns[:work_unit].stop_time.utc.should be_within(1.second).of(@time.utc)
        end
      end

      describe "with start time as 13:00 and empty stop time" do
        before :each do
          Timecop.travel(@local_tz.parse("May 5, 2013 14:00"))
        end

        it "should create a correct work unit" do
          @start = "13:00"
          expect do
            post :create, :work_unit => { :project_id => project.id,
              :start_time => @start.to_s, :time_zone => (@local_tz.utc_offset / 3600), :calculate => true
            }
          end.to change(WorkUnit, :count).by(1)
        end
      end


      describe "with start and stop times as strings" do
        it "should correctly calculate work interval" do
          @time = @local_tz.now
          @start = @local_tz.now - 2 * 60 * 60
          @stop = @start + 1.5 * 3600
          post :create, :work_unit => { :project_id => project.id,
            :start_time => @start.to_s(:long), :stop_time => @stop.to_s(:long), :time_zone => (@local_tz.utc_offset / 3600), :calculate => true
          }
          assigns[:work_unit].hours.should == 1.5
        end
      end

      describe "with a 20-minute work unit" do
        before :each do
          @start = @local_tz.parse("May 5, 2010 4:00").to_s(:date_and_time)
          @stop  = @local_tz.parse("May 5, 2010 4:20").to_s(:date_and_time)
        end
        it "should create a work unit" do
          lambda do
            post :create, :work_unit => { :project_id => project.id,
              :start_time => @start, :stop_time => @stop, :time_zone => (@local_tz.utc_offset / 3600), :calculate => true
            }
          end.should change(WorkUnit, :count).by(1)
          assigns[:work_unit].hours.should be_within(0.003).of(0.33)
        end
      end

      describe "for a work unit with a 'calc' hours" do
        before do
          @start = @local_tz.now - 2 * 60 * 60
          @stop = @start + 1.5 * 3600
          post :create, :work_unit => { :project_id => project.id,
            :start_time => @start.to_s, :stop_time => @stop.to_s, :time_zone => (@local_tz.utc_offset / 3600), :calculate => true
          }
        end

        it "should create a work unit with hours" do
          assigns[:work_unit].hours.should == 1.5
        end
      end

      describe "with valid params" do
        let :start_time do
          @local_tz.now.to_s
        end

        before do
          @valid_create_params = {
            :project_id => project.id,
            :start_time => @local_tz.now.to_s,
            :time_zone => (@local_tz.utc_offset / 3600),
            :annotation => {
              :description => "An annotation.",
              :action => "Annotation",
              :source => "User",
              :user_id => @user.id,
              :project_id => project.id
            }
          }

        end

        context "with html or js request content type" do

          it "should create a new work_unit in the database" do
            lambda do
              post :create, :work_unit => @valid_create_params
            end.should change(WorkUnit, :count).by(1)
          end

          it "should create a new annotation in the database" do
            lambda do
              post :create, :work_unit => @valid_create_params
            end.should change(Activity, :count).by(1)
          end

          it "should save the correct values of the annotation" do
            post :create, :work_unit => @valid_create_params
            expect(Activity.last.description).to eql("An annotation.")
          end

          it "should expose a saved work_unit as @work_unit" do
            post :create, :work_unit => @valid_create_params
            assigns[:work_unit].should be_a(WorkUnit)
          end

          it "should save the newly created work_unit as @work_unit" do
            post :create, :work_unit => @valid_create_params
            assigns[:work_unit].should_not be_new_record
          end

          it "should redirect to the created work_unit" do
            post :create, :work_unit => @valid_create_params
            new_work_unit = assigns[:work_unit]
            response.should redirect_to(work_unit_url(new_work_unit))
          end

          it "should set the work_unit's user to the current user" do
            post :create, :work_unit => @valid_create_params
            assigns[:work_unit].user.should == @user
          end

          it "should set the annotation's time to the work unit's stop time" do
            post :create, :work_unit => @valid_create_params
            new_work_unit = assigns[:work_unit]
            expect(Activity.last.time).to eq(new_work_unit.stop_time)
          end

          describe "and a blank annotation description" do

            before :each do
              @valid_create_params.deep_merge!(annotation: {description: ""} )
            end

            it "should create a new work_unit in the database" do
              lambda do
                post :create, :work_unit => @valid_create_params
              end.should change(WorkUnit, :count).by(1)
            end

            it "should not create a new annotation in the database" do
              lambda do
                post :create, :work_unit => @valid_create_params
              end.should_not change(Activity, :count)
            end
          end


          describe "and hours in HH:MM format" do
            it "should set the hours correctly" do
              post :create, :work_unit => @valid_create_params.merge!(:hours => "4:15")
              assigns[:work_unit].hours.should == 4.25
            end
          end

          describe "and JS accept type" do
            before do
              request.env['HTTP_ACCEPT'] = 'application/javascript'
              @user.current_project = project
              @user.save
            end
            it "should set the work units list" do
              post :create, :work_unit => @valid_create_params
              assigns(:work_units).should ==  @user.completed_work_units_for(@user.current_project).order(stop_time: :desc).paginate(:per_page => 10, :page => 1)
            end
          end
        end

        context "with json request content type" do
          # let :study_values do { :some => 'values' } end
          let :json_body    do @valid_create_params.to_json end
          let :work_unit    do FactoryGirl.build_stubbed(:work_unit) end

          before do
            request.headers['HTTP_ACCEPT'] = 'application/json'
            request.headers['Content-Type'] = 'application/json'
            WorkUnitMapper.stub(:new).and_return(mapper)
            mapper.stub(:save).and_return(work_unit)
          end

          context "successful create" do
            let :mapper do
              double(WorkUnitMapper, :save => true)
            end

            it "instantiates and saves a mapper" do
              #TODO complete this test when all is update to Rails 4
              # WorkUnitMapper.should_receive(:new).with(json_body)
              # mapper.should_receive(:save)
              # post :create, json_body, "CONTENT_TYPE" => 'application/json'
            end
          end

          # describe "and JSON format type" do
          #   it "should respond with json" do
          #     post :create, :work_unit => @valid_create_params, :format => :json
          #     response.body.should have_json_path("work_unit/billable")
          #     be_json_eql
          #   end
          # end
        end
      end

      describe "with invalid params" do
        def invalid_create_params
          #invalid because work units require a project
          @valid_create_params = {
            :project_id => nil,
            :start_time => @local_tz.now.to_s,
            :time_zone => (@local_tz.utc_offset / 3600)
          }
        end

        it "should not create a new work_unit in the database" do
          lambda do
            post :create, :work_unit => invalid_create_params
          end.should_not change(WorkUnit, :count)
        end

        it "should expose a newly created work_unit as @work_unit" do
          post :create, :work_unit => invalid_create_params
          assigns(:work_unit).should be_a(WorkUnit)
        end

        it "should expose an unsaved work_unit as @work_unit" do
          post :create, :work_unit => invalid_create_params
          assigns(:work_unit).should be_new_record
        end

        it "should re-render the 'new' template" do
          post :create, :work_unit => invalid_create_params
          response.should render_template('new')
        end
      end
    end

    ########################################################################################
    #                                      PUT UPDATE
    ########################################################################################
    describe "responding to PUT update" do
      before do
        session[:return_to] = root_path
      end

      describe "for a work unit with a start time and calculate = true" do
        before do
          @start = @local_tz.now - 2.5.hours
        end

        it "should redirect " do
          put :update, :id => @work_unit.id, :work_unit => {:project_id => project.id,
            :start_time => @start.to_s, :stop_time => "", :time_zone => (@local_tz.utc_offset / 3600), :calculate => "true", :hours => '2'
          }
          response.should redirect_to(root_path)
        end

        it "should create a work unit with a real stop time" do
          put :update, :id => @work_unit.id, :work_unit => {:project_id => project.id,
            :start_time => @start.to_s, :stop_time => "", :time_zone => (@local_tz.utc_offset / 3600), :calculate => "true", :hours => '2'
          }
          assigns[:work_unit].stop_time.should be_within(90.seconds).of(@local_tz.now.utc)
        end
      end

      describe "for a work unit with no hours but calculate = true" do
        before do
          @time = @local_tz.now
          start = @time - 2.hours
          stop = start + 1.5.hours
          put :update, :id => @work_unit.id, :work_unit => {
            :project_id => project.id,
            :start_time => start.to_s,
            :stop_time => stop.to_s,
            :time_zone => (@local_tz.utc_offset / 3600),
            :hours => nil, :calculate => "true"
          }
        end

        it "should expose the requested work_unit as @work_unit" do
          assigns(:work_unit).should == @work_unit
        end

        it "should create a work unit with hours" do
          assigns[:work_unit].hours.should be_within(0.001).of(1.5)
        end
      end

      describe "with valid params" do
        def valid_update_params
          { billable: false }
        end

        it "should update the requested work_unit in the database" do
          lambda do
            put :update, :id => @work_unit.id, :work_unit => valid_update_params
          end.should change{ @work_unit.reload.billable }.to(false)
        end

        it "should expose the requested work_unit as @work_unit" do
          put :update, :id => @work_unit.id, :work_unit => valid_update_params
          assigns(:work_unit).should == @work_unit
        end

        describe "hours in HH:MM" do
          it "should update hours correctly" do
            lambda do
              put :update, :id => @work_unit.id, :work_unit => valid_update_params.merge!( :hours => "3:45" )
            end.should change{ @work_unit.reload.hours }.to(3.75)
          end
        end
      end

      describe "with invalid params" do
        def invalid_update_params
          { :project_id => nil }
        end

        it "should not change the work_unit in the database" do
          lambda do
            put :update, :id => @work_unit.id, :work_unit => invalid_update_params
          end.should_not change{ @work_unit.reload }
        end

        it "should expose the work_unit as @work_unit" do
          put :update, :id => @work_unit.id, :work_unit => invalid_update_params
          assigns(:work_unit).should == @work_unit
        end

        it "should re-render the 'edit' template" do
          put :update, :id => @work_unit.id, :work_unit => invalid_update_params
          response.should render_template('edit')
        end
      end
    end


    ########################################################################################
    #                                      DELETE DESTROY
    ########################################################################################
    describe "DELETE destroy" do

      it "should reduce work_unit count by one" do
        lambda do
          delete :destroy, :id => @work_unit.id
        end.should change(WorkUnit, :count).by(-1)
      end

      it "should make the work_units unfindable in the database" do
        delete :destroy, :id => @work_unit.id
        lambda{ WorkUnit.find(@work_unit.id)}.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "should redirect to the work_units list" do
        delete :destroy, :id => @work_unit.id
        response.should redirect_back
      end

    end
  end
end
