module Api
  module V1
		class SessionController < ApplicationController
			before_action :set_variable

		 	def create
		 		current_user = User.find_by('email =?', params[:email]) if params[:email].present?
		 		if current_user.present?
		 			if current_user.password_digest.present?
		 				user_match = current_user.authenticate(params[:password])
		        if user_match.present?
		        	user_match.update(access_token:SecureRandom.hex)
		        	@code = 200
		        	@msg = "User successfully logged in"
		        	@data = User.find_detail(user_match)
		        end
		      end	
		 	  end
		 	  render json: { 'code' => @code, 'message' => @msg, 'data' => @data }
		 	end

		 	def set_variable
		 		@code = 400
		 		@msg = "Username and Password Mismatch!"
		 		@data = {}
		 	end

		end
	end	
end	
