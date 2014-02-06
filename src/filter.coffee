class filter

	biom = null
	pinch = null
	filename = null
	attr_length = null
	date_array = []
	no_data_attributes_array = []
	unknown_array = []
	attributes_array = []
	attributes_array_units = []
	groupable_array = []
	groupable_array_content = []
	columns_sample_name_array = [] # All sample names 
	columns_sample_count_list = [] # Each sample count
	columns_non_empty_sample_count = [] # Add up all columns 

	constructor: () -> 
		db.open(
			server: "BiomData", version: 1,
			schema:
				"biom": key: keyPath: 'id', autoIncrement: true,
		).done (s) => 
			s.biom.query().all().execute().done (results) => 
				currentData = results[results.length-1]
				filename = currentData.name
				biom = JSON.parse(currentData.data)
				pinch = JSON.parse(currentData.data)
				# Parse 		
				attr_length = biom.shape[1]-1
				@generateColumns()
				@generateColumnsSummary()
				@generateColumnsValues()
				@generateDate()

				# Build
				$("#file_numbers").append( "File: " + filename + ", Size: " + (parseFloat(currentData.size.valueOf() / 1000000)).toFixed(1) + " MB <br/><br />Observation: " + biom.shape[0] + ", Sample: " + biom.shape[1] )

				@generateLeftDates()
				@generateLeftNumeric()
				@generateLeftNonNumeric()
				@generateLeftGroupable()

				# remove the numbers and leave the string values
				if groupable_array_content.length > 0
					for i in [0..groupable_array_content.length-1]
						if typeof groupable_array_content[i] == 'number'
							groupable_array_content.splice( groupable_array_content.indexOf(groupable_array_content[i]),1 )

				@generateThumbnails()
				@livePreview()

	# 0 Jump to Gallery 

	jumpToGallery: () -> 
		db.open(
			server: "BiomSample", version: 1,
			schema:
				"biomSample": key: keyPath: 'id', autoIncrement: true,
		).done (s) => 
			sampleToStore = {}
			sampleToStore.name = filename
			sampleToStore.type = 'sampleIDs'
			sampleToStore.selected_sample = @selected_sample
			sampleToStore.groupable = groupable_array
			sampleToStore.selected_groupable_array = @selected_groupable_array
			sampleToStore.selected_attributes_array = @selected_attributes_array
			s.biomSample.add( sampleToStore ).done (item) -> 
				setTimeout( "window.location.href = 'viz.html'", 1000)		
				
	# 1 Parse Data 

	generateColumns: () ->
		
		for key of biom.columns[0].metadata
			if key.toLowerCase().indexOf("date") != -1
				date_array.push(key)

			else if (key.toLowerCase().indexOf("barcode") != -1) || (key.toLowerCase().indexOf("sequence") != -1) || (key.toLowerCase().indexOf("reverse") != -1) || (key.toLowerCase() == "internalcode") || (key.toLowerCase() == "description") || (key.toLowerCase().indexOf("adapter") !=-1)
				no_data_attributes_array.push(key)
		
			else if !isNaN(biom.columns[0].metadata[key].split(" ")[0].replace(",","")) || biom.columns[0].metadata[key] == "no_data" 
				idential_elements_in_array_flag = false

				for i in [0..attr_length]
					if biom.columns[i].metadata[key] != 'no_data'
						idential_elements_in_array = biom.columns[i].metadata[key]
						break

				for i in [0..attr_length]
					if biom.columns[i].metadata[key] != idential_elements_in_array and biom.columns[i].metadata[key] != 'no_data'
						idential_elements_in_array_flag = true

				if idential_elements_in_array_flag 
					attributes_array.push(key)
					for i in [0..attr_length]
						if biom.columns[i].metadata[key] != 'no_data'
							attributes_array_units.push(biom.columns[i].metadata[key].split(" ")[1])
				else 
					no_data_attributes_array.push(key)

			else if typeof key == 'string'
				groupable_array.push(key)
				starting_flag = groupable_array_content.length
				groupable_array_content.push(starting_flag)


				for i in [0..attr_length]
					flag = true
					if groupable_array_content.length > 0
						for j in [(starting_flag+1)..groupable_array_content.length-1]
							if biom.columns[i].metadata[key] == groupable_array_content[j]
								flag = false 
								break
						if flag 
							groupable_array_content.push(biom.columns[i].metadata[key])
				if groupable_array_content.length - starting_flag == 2 
					no_data_attributes_array.push(key)
					groupable_array.splice(groupable_array.length-1,1)
					groupable_array_content.splice(groupable_array_content.length-2, 2)
			else 
				unknown_array.push(key)

	generateColumnsSummary: () -> 
		columns_sample_total_count = 0 # Non empty sample ids, for new pinch file

		for i in [0..attr_length]
			columns_sample_count_list[i] = 0
			columns_sample_name_array.push(biom.columns[i].id)

		for i in [0..biom.data.length-1] 
			columns_sample_total_count += biom.data[i][2]
			columns_sample_count_list[biom.data[i][1]] += biom.data[i][2]

		for i in [0..attr_length]
			if columns_sample_count_list[i] > 0 
				columns_non_empty_sample_count.push(i)

	generateColumnsValues: () ->
		@columns_metadata_array = [] # All column data values 
		@columns_metadata_array = new Array(attributes_array.length)

		if attributes_array.length > 0
			for i in [0..attributes_array.length-1]
				@columns_metadata_array[i] = new Array(attr_length+1) 
			for i in [0..attr_length]
				for key of biom.columns[i].metadata
					for j in [0..attributes_array.length-1]
						if key == attributes_array[j]
							@columns_metadata_array[j][i] = parseFloat(biom.columns[i].metadata[key].split(" ")[0].replace(",","")) # in case there is between thousands
							if isNaN(@columns_metadata_array[j][i]) 
								@columns_metadata_array[j][i] = -99999

	generateDate: () -> 
		@formatted_date_array = new Array(date_array.length)
		@sorted_number_date_array_d = new Array(date_array.length)
		@sorted_number_date_array_freq = new Array(date_array.length)
		number_date_array = new Array(date_array.length)

		if date_array.length > 0
			for m in [0..date_array.length-1]
				@formatted_date_array[m] = [] 
				@sorted_number_date_array_d[m] = []
				@sorted_number_date_array_freq[m] = []			
				date_meta_key = date_array[m] 
				number_date_array[m] = []

				for i in [0..attr_length]
					ori_timestamp = biom.columns[i].metadata[date_meta_key]
					if ori_timestamp.length < 11 && ori_timestamp.indexOf(":") == -1 # No Hour Min Sec
						@formatted_date_array[m].push(moment(ori_timestamp).format("YYYY-MM-DD"))
						number_date_array[m].push(moment(ori_timestamp).format("YYYYMMDD"))
					else 
						@formatted_date_array[m].push(moment(ori_timestamp, "YYYY-MM-DDTHH:mm:ss Z").utc().format())
						number_date_array[m].push( moment(ori_timestamp, "YYYY-MM-DDTHH:mm:ss Z").utc().format("YYYYMMDDHHmmss") )
				
				@sorted_number_date_array_d[m] = @sortByFrequency(number_date_array[m])[0] 
				@sorted_number_date_array_freq[m] = @sortByFrequency(number_date_array[m])[1]		


	# 2 Build Panels 
	generateLeftDates: () -> 
		content = "" 
		@range_dates_array = []
		if date_array.length == 0 
			$('#att_head_dates').hide() 
		else 
			if date_array.length > 0
				for m in [0..date_array.length-1] 
					if @check_unique(@formatted_date_array[m]) 
						$('#dates').append("<div class = 'biom_valid_attr'><p>" + date_array[m] + ": " + @formatted_date_array[m][0] + "</p></div>")
						@range_dates_array[m] = new Array(2)
						@range_dates_array[m][0] = moment(@formatted_date_array[m][0]).utc().format("X")
						@range_dates_array[m][1] = moment(@formatted_date_array[m][0]).utc().format("X") 
					else 
						content += "<div class = 'biom_valid_attr_dates'>"
						content +=  date_array[m]
						content += "<div class = 'icon-expand-collapse-c' id= 'expend_collapse_dates_icon_" + (m + 1) + "'><i class='icon-expand-alt'></i></div>"

						# display smaller dates 
						if @sorted_number_date_array_d[m][0].length < 9
							content += 	"<p class='range_new_dates' id='range_dates_" + (m+1) + "_new'>" + moment(@sorted_number_date_array_d[m][0], "YYYYMMDD").format("MM/DD/YY") + " - " + moment(@sorted_number_date_array_d[m][@sorted_number_date_array_d[m].length-1], "YYYYMMDD").format("MM/DD/YY") + "</p>"
						else 
							content += 	"<p class='range_new_dates' id='range_dates_" + (m+1) + "_new'>" + moment(@sorted_number_date_array_d[m][0], "YYYYMMDDHHmmss").format("MM/DD/YY") + " - " + moment(@sorted_number_date_array_d[m][@sorted_number_date_array_d[m].length-1], "YYYYMMDDHHmmss").format("MM/DD/YY") + "</p>"

						content += "<div style='display: none;' id = 'expend_collapse_dates_" + (m+1) + "'>" + "<div class= 'biom_valid_att_thumbnail_dates' id='thumb_dates_" + (m+1) + "'></div>"
						content += "<div class='biom_valid_att_slider' id='slider_dates_" + (m+1) + "'></div>"

						if @sorted_number_date_array_d[m][0].length < 9 
							content += "<p class='range_left_dates' id='range_dates_" + (m+1) + "_left'>" + moment(@sorted_number_date_array_d[m][0], "YYYYMMDD").format("YYYY-MM-DD") + "</p>"
							content += "<p class='range_right_dates' id='range_dates_" + (m+1) + "_right'>" + moment(@sorted_number_date_array_d[m][@sorted_number_date_array_d[m].length-1], "YYYYMMDD").format("YYYY-MM-DD") + "</p>"
							min_timestamp = moment(@sorted_number_date_array_d[m][0], "YYYYMMDD").utc().format("X")
							max_timestamp = moment(@sorted_number_date_array_d[m][@sorted_number_date_array_d[m].length-1], "YYYYMMDD").utc().format("X")
						else 
							content += "<p class='range_left_dates' id='range_dates_" + (m+1) + "_left'>" + moment(@sorted_number_date_array_d[m][0], "YYYYMMDDHHmmss").format("YYYY-MM-DD<br/>HH:mm:ss") + "</p>"
							content += "<p class='range_right_dates' id='range_dates_" + (m+1) + "_right'>" + moment(@sorted_number_date_array_d[m][@sorted_number_date_array_d[m].length-1], "YYYYMMDDHHmmss").format("YYYY-MM-DD<br/>HH:mm:ss") + "</p>"
							min_timestamp = moment(@sorted_number_date_array_d[m][0], "YYYYMMDDHHmmss Z").utc().format("X")
							max_timestamp = moment(@sorted_number_date_array_d[m][@sorted_number_date_array_d[m].length-1], "YYYYMMDDHHmmss Z").utc().format("X")

						content += "</div></div>"
						$('#dates').append(content) 

						$('#expend_collapse_dates_icon_' + (m + 1) ).click (event) => 
							id = event.currentTarget.id.replace('expend_collapse_dates_icon_','') 
							if $('#expend_collapse_dates_' + id).attr('style') == 'display: none;'
								$('#expend_collapse_dates_' + id).show()
								$('#expend_collapse_dates_icon_' + id).html('<i class="icon-collapse-alt"></i>') 
							else
								$('#expend_collapse_dates_' + id).hide()
								$('#expend_collapse_dates_icon_' + id).html('<i class="icon-expand-alt"></i>')

						@drawBasicBars( '#thumb_dates_' + (m+1), null, @sorted_number_date_array_freq[m], null, [250, 50] )
						$('#slider_dates_' + (m+1)).width( $('#thumb_dates_' + (m+1) + ' svg').attr('width') - 2 )

						@range_dates_array[m] = new Array(2)
						@range_dates_array[m][0] = min_timestamp 
						@range_dates_array[m][1] = max_timestamp

						$( "#slider_dates_" + (m+1)).slider({
							range: true,
							min: 0,
							max: @sorted_number_date_array_freq[m].length-1,
							step: 1,
							values: [ 0, @sorted_number_date_array_freq[m].length-1 ],
							slide: ( event, ui ) => 
								id = event.target.id.replace("slider_dates_","")
								$("#range_dates_" + id + "_new").text( "[" + moment(@sorted_number_date_array_d[id-1][ui.values[0]], "YYYYMMDD").format("MM/DD/YY") + " — " + moment(@sorted_number_date_array_d[id-1][ui.values[1]], "YYYYMMDD").format("MM/DD/YY") + "]")
								if @sorted_number_date_array_d[id-1][ui.values[0]].length < 9 
									@range_dates_array[id-1][0] = moment(@sorted_number_date_array_d[id-1][ui.values[0]],"YYYYMMDD").utc().format("X")
									@range_dates_array[id-1][1] = moment(@sorted_number_date_array_d[id-1][ui.values[1]],"YYYYMMDD").utc().format("X")
								else 
									@range_dates_array[id-1][0] = moment(@sorted_number_date_array_d[id-1][ui.values[0]], "YYYYMMDDHHmmss").utc().format("X")
									@range_dates_array[id-1][1] = moment(@sorted_number_date_array_d[id-1][ui.values[1]], "YYYYMMDDHHmmss").utc().format("X")
								@livePreview()
						})

	generateLeftNumeric: () ->
		if attributes_array.length == 0 
			$('#att_head_numeric').hide()
		else 
			if attributes_array.length > 0
				for i in [0..attributes_array.length-1]
					content = ""
					content += "<input type='checkbox' name='numeric_check_group' id='numeric_check_" + (i+1) + "' checked='checked' /><label for='numeric_check_" + (i+1) + "'></label>"
					content += "<span class = 'biom_valid_attr' id='att_" + (i+1) + "'>" + attributes_array[i] + "</span>"
					
					if (typeof(attributes_array_units[i]) != 'undefined' && attributes_array_units[i] != null)
						content += "<input type='text' class='biom_valid_attr_units' id='unit_" + (i+1) + "' placeholder='" + attributes_array_units[i] + "'>"

					content += "<div class = 'icon-expand-collapse-c' id= 'expend_collapse_icon_" + (i+1) + "'><i class='icon-expand-alt'></i></div>" 
					content += "<div class='biom_valid_att_thumbnail_sm' id='thumb_sm_" + (i+1) + "'></div>"
					content += "<p class='range_new' id='range_" + (i+1) + "_new'></p>"
					content += "<div style='display: none;' id = 'expend_collapse_" + (i+1) + "'>" + "<div class='biom_valid_att_thumbnail' id='thumb_" + (i+1) + "'></div>" 
					content += "<div class='biom_valid_att_slider' id='slider_" + (i+1) + "'></div>" 
					content += "<div class='blackSticks'></div>"
					content += "<p class='range_left' id='range_" + (i+1) + "_left'></p>" 
					content += "<p class='range_right' id='range_" + (i+1) + "_right'></p>" 
					content += "<p class='biom_valid_notes' id='att_note_" + (i+1) + "'></p></div>" 

					$('#numeric_att').append("<div>" + content + "</div>")

					$('#expend_collapse_icon_' + (i+1) ).click (event) =>
						id = event.currentTarget.id.replace('expend_collapse_icon_','') 
						if $('#expend_collapse_' + id).attr('style') == 'display: none;'
							$('#expend_collapse_' + id).show()
							$('#att_' + id).css('font-weight', 'bold')
							$('#unit_' + id).show()
							$('#range_' + id + '_new').show()
							$('#thumb_sm_' + id).hide()
							$('#expend_collapse_icon_' + id).html('<i class="icon-collapse-alt"></i>') 
						else		
							$('#expend_collapse_' + id).hide()
							$('#att_' + id).css('font-weight', 'normal')
							$('#unit_' + id).hide()
							$('#range_' + id + '_new').hide()
							$('#thumb_sm_' + id).show()
							$('#expend_collapse_icon_' + id).html('<i class="icon-expand-alt"></i>')

					$('#numeric_check_' + (i+1) ).click () => @livePreview() 

	generateLeftNonNumeric: () ->
		if no_data_attributes_array.length == 0
			$('#att_head_descriptive').hide()
		else 
			if no_data_attributes_array.length > 0
				for i in [0..no_data_attributes_array.length-1] 
					content = ""
					content += "<input type='checkbox' name='non_numeric_check_group' id='non_numeric_check_" + (i+1)  + "' /><label for='non_numeric_check_" + (i+1) + "'></label><span class = 'biom_valid_attr'>" + no_data_attributes_array[i] + "</span>"
					$('#non_numeric_att').append("<div>" + content + "</div>")

					$('#non_numeric_check_' + (i+1)).click () => @livePreview()

	generateLeftGroupable: () ->
		pointer_left = 1
		pointer_right = groupable_array_content.length-1
		check_count = 1

		if groupable_array.length == 0	 
			$('#att_head_groupable').hide()
		else 
			if groupable_array.length > 0
				for i in [0..groupable_array.length-1] 
					flag = true 
					toprocess = []

					content = "" 
					content += "<span class = 'biom_valid_attr'>" + groupable_array[_i] + "</span><br/>"

					if groupable_array_content.length > 0
						for j in [pointer_left..groupable_array_content.length-1]
							if groupable_array_content[j] == j 
								pointer_right = j 
								flag = false
								break
						if flag 
							toprocess = groupable_array_content.slice(pointer_left, groupable_array_content.length)
						else 
							toprocess = groupable_array_content.slice(pointer_left, pointer_right)
							pointer_left = pointer_right + 1
							pointer_right = groupable_array_content.length-1

						if toprocess.length > 0
							for k in [0..toprocess.length-1]
								content += "<input type='checkbox' name='groupable_check_group' id='groupable_check_" + check_count + "' checked='checked' /><label for='groupable_check_" + check_count + "'></label><span class = 'biom_valid_attr_grp'>" + toprocess[_k] + "</span><br/>"	
								check_count++

							$('#groupable_att').append("<div>" + content + "</div>")

							for k in [0..toprocess.length-1]
								$('#groupable_check_' + (k+1) ).click () => @livePreview()

	generateThumbnails: () ->
		@range_array = []

		@lines_array = new Array(@columns_metadata_array.length)
		if @columns_metadata_array.length > 0
			step = new Array(@columns_metadata_array.length)  # keeps the step value between each bar

			for i in [0..@columns_metadata_array.length-1]
				nan_values = 0
				each_numeric_linechart = @sortByFrequency(@columns_metadata_array[i])

				if each_numeric_linechart[0][0] == -99999 
					nan_values = each_numeric_linechart[1][0]
					each_numeric_linechart[0].shift()
					each_numeric_linechart[1].shift()
				if nan_values > 0 
					$("#att_note_" + (i+1)).text("* This column has " + nan_values + " empty values.")

				@lines_array[i] = new Array(2)
				@lines_array[i][0] = each_numeric_linechart[0]
				@lines_array[i][1] = each_numeric_linechart[1]
				each_numeric_linechart_min = Math.min.apply(Math, each_numeric_linechart[0])
				each_numeric_linechart_max = Math.max.apply(Math, each_numeric_linechart[0]) 
				
				@drawBasicBars( '#thumb_' + (i+1), each_numeric_linechart[0], each_numeric_linechart[1], null, [250, 50] )
				@drawBasicBars( '#thumb_sm_' + (i+1), each_numeric_linechart[0], each_numeric_linechart[1], null, [130, 15])

				@range_array[i] = new Array(2)
				@range_array[i][0] = each_numeric_linechart_min 
				@range_array[i][1] = each_numeric_linechart_max
				step[i] = (each_numeric_linechart_max - each_numeric_linechart_min) / each_numeric_linechart[1].length

				$('#slider_' + (i+1)).width( $('#thumb_' + (i+1) + ' svg').attr('width') - 2 )
				$( "#slider_" + (i+1)).slider({
					range: true,
					min: each_numeric_linechart_min,
					max: each_numeric_linechart_max,
					step: (each_numeric_linechart_max - each_numeric_linechart_min) / each_numeric_linechart[1].length, # step for adjustment, get the min between unit & 1
					values: [ each_numeric_linechart_min, each_numeric_linechart_max ],
					slide: ( event, ui ) =>
						id = event.target.id.replace("slider_","")
						if ui.value == ui.values[0]
							order = Math.round( (ui.values[ 0 ] - @lines_array[id-1][0][0]) / step[id-1] ) 
							leftValue = @lines_array[id-1][0][order]
							@range_array[id-1][0] = leftValue # ui.values[0]
							$("#range_" + id + "_left").text(  leftValue ).css('margin-left', Math.max( event.clientX - 40, 20) )
							$("#range_" + id + "_new").text( "range: [" + leftValue + " — " + @range_array[id-1][1] + "]")
						else
							order = Math.round( ( ui.values[ 1 ] - @lines_array[id-1][0][0]) / step[id-1] ) - 1
							rightValue = @lines_array[id-1][0][order]
							@range_array[id-1][1] = rightValue # ui.values[1]
							$("#range_" + id + "_right").text( rightValue ).css('margin-left', Math.min( event.clientX - 40, 270) )
							$("#range_" + id + "_new").text( "range: [" + @range_array[id-1][0] + " — " + rightValue + "]")

						$('#numeric_check_' + id).prop('checked', true)
						@drawBasicBars( '#thumb_sm_' + id, @lines_array[id-1][0], @lines_array[id-1][1], @range_array[id-1], [130, 15])  # values - ui.values
						@livePreview()
				})

				$( "#range_" + (i+1) + "_left").text( each_numeric_linechart_min )
				$( "#range_" + (i+1) + "_right").text(each_numeric_linechart_max ) 
				$( "#range_" + (i+1) + "_new").text("range: [" +  each_numeric_linechart_min  + " — " + each_numeric_linechart_max + "]" )

	# 3 Live Preview
	livePreview: () -> 
		@selected_sample = []
		@selected_groupable_array = []
		@selected_attributes_array = []
		@selected_no_data_attributes_array = []
		selected_range_array = []

		if attributes_array.length > 0
			for i in [1..attributes_array.length]
				if $('#numeric_check_' + i).is(':checked') 
					@selected_attributes_array.push(attributes_array[i-1])

		if no_data_attributes_array.length > 0
			for i in [1..no_data_attributes_array.length] 
				if $('#non_numeric_check_' + i).is(':checked') 
					@selected_no_data_attributes_array.push(no_data_attributes_array[i-1])

		if groupable_array_content.length > 0
			for i in [1..groupable_array_content.length]
				if $('#groupable_check_' + i).is(':checked')
					@selected_groupable_array.push(groupable_array_content[i-1])

		if @range_array.length > 0
			for i in [1..@range_array.length] 
				if $('#numeric_check_' + i).is(':checked')
					selected_range_array.push(@range_array[i-1])

		$('#right_live_panel').html("")

		# Step 1
		for i in [0..biom.shape[1]-1] 
			@selected_sample.push(i)

		if selected_range_array.length > 0
			for i in [0..selected_range_array.length-1] 
				key = @selected_attributes_array[i]
				for r in [0..biom.shape[1]-1]
					if biom.columns[r].metadata[key].split(" ")[0] < selected_range_array[i][0] || biom.columns[r].metadata[key].split(" ")[0] > selected_range_array[i][1]
						delete_index = @selected_sample.indexOf(r) 
						if delete_index != -1 then @selected_sample.splice(delete_index,1)
		
		if date_array.length > 0
			for i in [0..date_array.length-1]
				key = date_array[i]
				for r in [0..biom.shape[1]-1]
					current_timeStamp = biom.columns[r].metadata[key]
					if current_timeStamp.length < 11 # and current_timeStamp.indexOf(":") != -1 
						formatted_timeStamp = moment(current_timeStamp).utc().format("X")
					else 
						formatted_timeStamp = moment(current_timeStamp, "YYYY-MM-DDTHH:mm:ss Z").utc().format("X")
					if formatted_timeStamp < @range_dates_array[i][0] || formatted_timeStamp > @range_dates_array[i][1]
						delete_index = @selected_sample.indexOf(r) 
						if delete_index != -1 
							@selected_sample.splice(delete_index,1)
							# console.log 'sample #' + delete_index + ' doesn't meet date range 

		# Step 2 
		if groupable_array.length > 0
			for i in [0..groupable_array.length-1]
				for k in [0..biom.shape[1]-1]
					flag = true 
					if @selected_groupable_array.length > 0
						for r in [0..@selected_groupable_array.length-1] 
							if biom.columns[k].metadata[ groupable_array[i] ] == @selected_groupable_array[r]
								flag = false 
								break 
						if flag 
							delete_index = @selected_sample.indexOf(k)
							if delete_index != -1 then @selected_sample.splice(delete_index,1)
					else if @selected_groupable_array.length == 0 
						@selected_sample = []

		# 	Add one more step here: get rid of _empty_sample_count, leave only the valid samples
		delete_index = []	
		if @selected_sample.length > 0
			for i in [0..@selected_sample.length-1]
				flag = true 
				if columns_non_empty_sample_count.length > 1
					for j in [0..columns_non_empty_sample_count.length-1]
						if columns_non_empty_sample_count[j] == @selected_sample[i]
							flag = false
							break 
					if flag 
						delete_index.push(@selected_sample[i])
						console.log 'Sample ' + (i+1) + ' has 0 count'

		if delete_index.length > 0
			for i in [0..delete_index.length-1] 
				@selected_sample.splice(@selected_sample.indexOf(delete_index[i]), 1)
		
		# Step 3 Now based on the filters, selected sample now contains all the right sample # within that range.
		content = "<table id='myTable'><thead><tr><th class = 'headerID myTableHeader'>ID</th><th class = 'headerID myTableHeader'>Sample ID" + "</th><th class='myTableHeader'>Sample Name</th><th class='headerCount myTableHeader'>Count</th></thead>"
		if @selected_sample.length > 0
			for i in [0..@selected_sample.length-1] 
				content += '<tr><td>' +  i + '</td><td>' + @selected_sample[i] + '</td><td>' + columns_sample_name_array[@selected_sample[i]] + '</td><td>' + columns_sample_count_list[@selected_sample[i]] + '</td></tr>'
		content += "</table>"
		$("#right_live_panel").append(content)

		$('#myTable').dataTable({
			"iDisplayLength": 50,
			"oLanguage": {
			# "sLengthMenu": "_MENU_ samples per page",
			"sLengthMenu": "",
			"sZeroRecords": "Nothing found - sorry",
			"sInfo": "Showing _START_ to _END_ of _TOTAL_ Samples",
			"sInfoEmpty": "Showing 0 to 0 of 0 Samples",
			"sInfoFiltered": "(filtered from _MAX_ total samples)"
			}
		})

		console.log 'selected_sample: ' + @selected_sample.length

	# 4 Download
	downloadPinch: () ->
		
		pinch.generated_by = 'Phinch 1.0'
		pinch.date = new Date() 

		# Step 1 - get data matrix ready 

		pinch_data_matrix = []
		sum_rows = new Array(biom.shape[0])
		for i in [0..biom.shape[0]-1] 
			sum_rows[i] = 0 
		index = 0 
		for i in [0..biom.data.length-1]
			flag = false 
			for j in [0..@selected_sample.length-1]
				if biom.data[i][1] == @selected_sample[j] # is selected 
					flag = true 
					break 
			if flag 
				pinch_data_matrix[index] = new Array(3) 
				pinch_data_matrix[index] = [biom.data[i][0], j ,biom.data[i][2]] 
				sum_rows[biom.data[i][0]] += biom.data[i][2]
				index++ 
		pinch.data = pinch_data_matrix		

		# Step 2 - get columns ready 

		for i in [0..biom.shape[1]-1]
			# if @selected_sample.indexOf(i) == -1 # unselected samples 
			# 	for key of pinch.columns[i].metadata
			# 		if key.toLowerCase().indexOf("date") == -1 # exclude the date columns 
			# 			pinch.columns[i].metadata[key] = 'no_data' # pinch.columns[i].metadata[key] + '_unselected'
		

			# If this is a not selected descriptive attribute, delete it 
			for j in [0..no_data_attributes_array.length-1]
				if @selected_no_data_attributes_array.indexOf(no_data_attributes_array[j]) == -1 
					@removeFromObjectByKey(pinch.columns[i].metadata, no_data_attributes_array[j])

			# If this is not a selected attributes, delete it 
			for k in [0..attributes_array.length-1]
				if @selected_attributes_array.indexOf(attributes_array[k]) == -1 
					@removeFromObjectByKey(pinch.columns[i].metadata, attributes_array[k])

		# Step 3 - get rows ready 
		valid_rows_count = 0 
		for i in [0..sum_rows.length-1]
			if parseInt(sum_rows[i]) > 0 
				valid_rows_count++
			else 
				pinch.rows[i].metadata.taxonomy = ["k__", "p__", "c__", "o__", "f__", "g__", "s__"]

		pinch.shape[1] = @selected_sample.length
		# Step 4 - stringify 				
		obj = JSON.stringify(pinch)
		blob = new Blob([obj], {type: "text/plain;charset=utf-8"})
		saveAs(blob, filename+".phinch")

	# 5 Utilities & Control Parts
	check_unique: (arr) ->
		arr = $.grep arr, (v, k) -> 
			return $.inArray(v ,arr) is k
		if arr.length == 1 then return true else return false

	sortByFrequency: (arr) -> 
		a = []
		b = [] 
		arr.sort(@numberSort)
		for i in [0..arr.length-1]
			if arr[i] != prev 
				a.push(arr[i])
				b.push(1)
			else 
				b[b.length-1]++
			prev = arr[i]
		return [a,b]

	numberSort: (a,b) -> return a - b

	removeFromObjectByKey: (thisObject, key) -> delete thisObject[key]	

	drawBasicBars: (div, each_numeric_linechart0, each_numeric_linechart1, values, size) => 

		d3.select(div + " svg").remove()
		max_single = d3.max( each_numeric_linechart1 )
		y = d3.scale.linear().domain([0, max_single]).range([1, size[1] ])
		eachBarWidth = (size[0] + 2) / each_numeric_linechart1.length - 2

		tooltipOverPanel = d3.select(div)
			.append("div")
			.attr('class', 'tooltipOverSmallThumb')
			.style("visibility", "hidden")

		tempViz = d3.select(div).append("svg")
			.attr("width", size[0] )
			.attr("height", size[1] )

		tempBar = tempViz.selectAll('rect').data(each_numeric_linechart1)
			.enter().append("rect")
			.attr('height', (d) -> return y(d) )
			.attr('width', Math.max(0.1, eachBarWidth) + 'px')
			.attr('x',  (d,i) -> return i * (eachBarWidth  + 2) )
			.attr('y', (d,i) -> return size[1] - y(d) )
			.attr('fill', (d,i) ->
				if values == null
					return '#444'
				else if values != null and each_numeric_linechart0[i] >= values[0] and each_numeric_linechart0[i] <= values[1]
					return '#adccd5'
				else 
					return '#aaa'
			)
			.on('mouseover', (d,i) -> 
				tooltipOverPanel.html( 'Value: ' + each_numeric_linechart0[i] + ', Freq: ' + d )
				tooltipOverPanel.style( { "visibility": "visible", top: (d3.event.pageY ) + "px", left: (d3.event.pageX + 10) + "px" })
			)
			.on('mouseout', (d) -> 
				tooltipOverPanel.style("visibility", "hidden")
			)


window.filter = filter




