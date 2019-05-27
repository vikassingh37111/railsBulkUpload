module QuestionsUploader

	def self.get_line_data line
		if line.match(/^\s*\d+\s*\./)
			return { 
				:type => 'question', 
				:number => line.match(/^\s*\d+\s*/)[0].strip, 
				:text => line.sub(/^\s*\d+\s*\./,'')
			}
		elsif line.match(/^\s*\(.*\)\s*/)
			return {
				:type => 'option', 
				:number => line.match(/^\s*\(.*\)\s*/)[0].gsub(/\(|\)/ , '').strip, 
				:text => line.sub(/^\s*\(.*\)\s*/,'')
			}
		elsif line.match(/^\s*[Ss]olution\s*:/)
			return {
				:type => 'solution', 
				:solutions => line.sub(/^\s*[Ss]olution\s*:/, '').gsub(/\(|\)/ , '').split(',').map(&:strip)
			}
		else
			return {
				:type => 'error', 
				:message => 'Discrepant Line Found. Please Check File'
			}
		end
	end

	def self.check_duplicate_option_number current_question, option_number
		option_number.in? current_question[:options].map{|option| option[:option_number]}
	end

	def self.upload_qna_file filename
		qna = []

		error_occured = false
		lineNumber = 0
		File.open("public/#{filename}" , 'r') do |f|
		  f.each_line do |line|
		  	line.strip!
		  	next if line.empty?
		    lineData = self.get_line_data line
		    if lineData[:type] == 'error'
		   		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: #{lineData[:message]}"  
		   		error_occured = true 	
		    	break
		    
		    elsif lineData[:type] == 'question'
		    	question_number = lineData[:number]
		    	question_text = lineData[:text]
		    	qna.push({:question_number => question_number, :question_text => question_text, :options => []})
		    
		    elsif lineData[:type] == 'option'
					current_question = qna.last
		    	option_number = lineData[:number]
		    	option_text = lineData[:text]
		    	option_sequence = current_question[:options].length > 0 ? current_question[:options].last[:option_sequence] + 1 : 1
		    	if option_number.blank?
		    		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: Blank option number"
		    		error_occured = true 	
		    		break
		    	elsif self.check_duplicate_option_number current_question, option_number
		    		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: Duplicate option found (#{option_number})"
		    		error_occured = true 	
		    		break
		    	else
		    		current_question[:options].push({:option_number => option_number, :option_text => option_text, :option_sequence => option_sequence})
		    	end

		    elsif lineData[:type] == 'solution'
		    	current_question = qna.last
		    	solutions = lineData[:solutions]
		    	correct_options_found = false
		    	current_question[:options].each do |option|
		    		if option[:option_number].in? solutions
		    			option[:correct] = true
		    			correct_options_found = true
		    		end
		    	end
		    	unless correct_options_found
		    		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: Solution not found in any of the options"
		    		error_occured = true 	
		    		break
		    	end
		    end
				lineNumber += 1
		  end
		end

		# Passing a hash now 
		# This can be used to directlt pass a json
		self.upload_qna_json_to_db(qna) unless error_occured
	end

	def self.skip_already_uploaded data		
		question_numbers = data.map{|question| question[:question_number]}
		already_uploaded_question_numbers = Question.where(:question_number => question_numbers).pluck(:question_number)
		data = data.reject{|question| question[:question_number].to_i.in? already_uploaded_question_numbers}
	end

	# Bulk Insert
	def self.upload_qna_json_to_db data
		# User 0 represents backend job
		current_user = 0 unless current_user.present?
		data = self.skip_already_uploaded data

		ActiveRecord::Base.transaction do
  		questions = []
			data.each do |question|
			  question_obj = Question.new(
			  	question_number: question[:question_number], 
			  	text: question[:question_text],
			  	created_by: current_user,
			  	updated_by: current_user
			  )
				question[:options].each do |option|
					question_obj.options.build(
						option_number: option[:option_number], 
						text: option[:option_text],
						sequence: option[:option_sequence],
						correct: option[:correct],
			  		created_by: current_user,
			  		updated_by: current_user
					)
				end
				questions << question_obj
			end
			Question.import questions, recursive: true
		end
	end 

end