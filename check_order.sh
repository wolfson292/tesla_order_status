#!/bin/bash

source settings.sh

check_diff () {
	tmp_diff=$(mktemp)
	diff -u <(cat $base_dir/last.$1.html | js-beautify | grep -v "\"form\"" | grep -v adyen) <(cat $base_dir/$current_time.$1.html | js-beautify | grep -v "\"form\"" | grep -v adyen ) > $tmp_diff
        if [ `cat $tmp_diff | wc -l | awk '{print \$1}'` -gt "0" ]
        then
		tmp=$(mktemp)
                echo "$2 Diff $current_time"
		echo "Diff" > $tmp
                cat $tmp_diff > $tmp
                echo "" >> $tmp
                echo "" >> $tmp
		echo "Full" >> $tmp
		cat $base_dir/$current_time.$1.html | js-beautify  >> $tmp

                aws ses send-email --from $from_addr --to $to_addr --subject "Tesla Order Status - $order_num - $2  Changed" --text "`cat $tmp | head -n 100`"
                cp $base_dir/$current_time.$1.html $base_dir/change.$current_time.$1.html
		rm $tmp
        fi
	cp $base_dir/$current_time.$1.html $base_dir/last.$1.html
	cat $base_dir/last.$1.html | js-beautify > $base_dir/pretty.$1.html
	rm $tmp_diff

} 


while true
do

	find ${base_dir}/ -mtime +5 -type f -name "*.html" -not -name "change*" -not -name "*last*" -exec rm {} \;

	current_time=$(date "+%Y.%m.%d-%H.%M.%S")
	new_file=$current_time.html
	echo "Checking $current_time"
	timeout -s SIGTERM 90 curl --silent -b $base_dir/cookies.txt -c $base_dir/cookies.txt -o $base_dir/$new_file "https://www.tesla.com/teslaaccount/product-finalize?rn=$order_num" 
        timeout -s SIGTERM 90 curl --silent -b $base_dir/cookies.txt -c $base_dir/cookies.txt -o $base_dir/$current_time.doclist.html "https://www.tesla.com/teslaaccount/document-hub/get-list"

	if [ -s "$base_dir/$new_file" ]
	then 

		grep "CarConfiguration" $base_dir/$new_file > $base_dir/$current_time.config.html
		grep "Tesla\.Tradein" $base_dir/$new_file > $base_dir/$current_time.tradein.html
		grep "Tesla\.ProductF" $base_dir/$new_file > $base_dir/$current_time.product.html
		grep "Drupal\.settings" $base_dir/$new_file > $base_dir/$current_time.settings.html
		grep "BUILD_TAG" $base_dir/$new_file > $base_dir/$current_time.build.html

		check_diff "config" "Config"
		check_diff "tradein" "Trade In"
		check_diff "product" "Product"
		check_diff "settings" "Settings"
		check_diff "build" "Website Version"

		if [ -s "$base_dir/$current_time.doclist.html" ]
        	then 
			check_diff "doclist" "Document List"
		else
			aws ses send-email --from $from_addr --to $to_addr --subject "Tesla Order Status - $order_num - Error" --text "Unable to Fetch Document List"
		fi
		cp $base_dir/$new_file $base_dir/last.html
	else
		aws ses send-email --from $from_addr --to $to_addr --subject "Tesla Order Status - $order_num - Error" --text "Unable to Fetch Order"
	fi




        echo "Done"
        sleep $((300 + RANDOM % 10))

done
