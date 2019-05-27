def QuestionsUploader
	extend ActiveSupport::Concern

	def getLineData line
		if line.match(/^\s*\d+\s*\./)
			return { 
				:type => 'question', 
				:number => line.match(/^\s*\d+\s*/)[0].strip, 
				:text => line.sub(/^\s*\d+\s*\./,'')
			}
		elsif line.match(/^\s*\(\s*\)\s*/)
			return {
				:type => 'option', 
				:number => line.match(/^\s*\d+\s*/)[0].gsub(/\(|\)/ , '').strip, 
				:text => line.sub(/^\s*\(\s*\)\s*/,'')
			}
		elsif line.match(/^\s*[Ss]olution\s*:/)
			return {
				:type => 'solution', 
				:solutions => line.sub(/^\s*[Ss]olution\s*:/).gsub(/\(|\)/ , '').split(',')
			}
		else
			return {
				:type => 'error', 
				:message => 'Discrepant Line Found. Please Check File'
			}
		end
	end

	def check_duplicate_option_number current_question, option_number
		option_number.in? current_question[:options].map{|option| option[:option_number]}
	end

	def upload_qna_file file
		qna = []

		lineNumber = 0
		File.open('/public/qna_file', 'r') do |f|
		  f.each_line do |line|
		  	line.strip!
		  	next if line.empty?
		    lineData = getLineData line
		    if lineData[:type] == 'error'
		   		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: #{lineData[:message]}"   	
		    	break
		    
		    elsif lineData[:type] == 'question'
		    	question_number = lineData[:number]
		    	question_text = lineData[:text]
		    	qna.push {:question_number => question_number, :question_text => question_text, :options => []}
		    
		    elsif lineData[:type] == 'option'
					current_question = qna.last
		    	option_number = lineData[:number]
		    	option_text = lineData[:text]
		    	option_sequence = current_question[:options].length > 0 ? current_question[:options].last[:option_sequence] + 1 : 1
		    	if option_number.blank?
		    		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: Blank option number"
		    		break
		    	if check_duplicate_option_number current_question, option_number
		    		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: Duplicate option found (#{option_number})"
		    		break
		    	else
		    		current_question[:options].push {:option_number => option_number, :option_text => option_text, :option_sequence => option_sequence}
		    	end

		    elsif lineData[:type] == 'solution'
		    	current_question = qna.last
		    	solutions = lineData[:solutions]
		    	correct_options_found = false
		    	current_question[:options].each do |option|
		    		option[:correct] = true if option[:option_number].in? solutions
		    		correct_options_found = true
		    	end
		    	unless correct_options_found
		    		puts "Upload Failed: \nLine #{lineNumber}: #{line} \n Error: Solution not found in any of the options"
		    		break
		    	end
		    end
				lineNumber += 1
		  end
		end

		# Passing a hash now 
		upload_qna_json_to_db(qna)
	end

	# Bulk Insert
	def upload_qna_json_to_db data
		ActiveRecord::Base.transaction do
  		questions = []
			data.each do |question|
			  question = Question.new(
			  	question_number: question[:question_number], 
			  	text: question[:question_text], 
			  	created_by: current_user, 
			  	updated_by: current_user
			  )
				question[:options].each do |option|
					question.options.build(
						option_number: option[:option_number], 
						text: option[:option_text],
						sequence: option[:option_sequence],
						correct: option[:correct],
						created_by: current_user,
						updated_by: current_user
					)
				end
				questions << question
			end
			Question.import questions, recursive: true
		end
	end 
	
end