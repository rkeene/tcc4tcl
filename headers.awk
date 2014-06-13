/^End of search list/{
	in_searchpath = 0;
}

(in_searchpath == 1){
	searchpath = $0;
	sub(/^  */, "", searchpath);
	sub(/  *$/, "", searchpath);

	searchpaths[searchidx] = searchpath "/";
	searchidx++;
}

/#include <\.\.\.> search starts here:/{
	in_searchpath = 1;
	searchidx = 0;
}

/^# [0-9][0-9]* /{
	file = $3;

	sub(/^"/, "", file);
	sub(/"$/, "", file);

	if (file ~ /</) {
		next;
	}

	if (file !~ /\.h$/) {
		next;
	}

	destfile = file;
	longestmatchlen = -1;
	for (idx = 0; idx < searchidx; idx++) {
		len = length(searchpaths[idx]);
		if (substr(destfile, 1, len) == searchpaths[idx]) {
			if (len > longestmatchlen) {
				longestmatchidx = idx;
				longestmatchlen = len;
			}
		}
	}

	while(sub(/\/\/*[^\/]*\/\.\.\/\/*/, "/", file)) {}

	if (longestmatchlen > 0) {
		idx = longestmatchidx;

		destfile = substr(destfile, longestmatchlen + 1);

		while(sub(/\/\/*[^\/]*\/\.\.\/\/*/, "/", destfile)) {}
	} else {
		while(sub(/\/\/*[^\/]*\/\.\.\/\/*/, "/", destfile)) {}

		if (!sub(/^.*\/include\//, "", destfile)) {
			next;
		}
	}

	copy[file,idx] = destfile;
}

END{
	for (key in copy) {
		split(key, parts, SUBSEP);

		src = parts[1];
		idx = strtonum(parts[2]);
		dest = copy[key];

		destcopy[dest,idx] = src;
		destcopyfiles[dest] = 1;
	}

	for (destfile in destcopyfiles) {
		outidx = 0;
		for (idx = 0; idx < searchidx + 1; idx++) {
			if (destcopy[destfile,idx]) {
				srcfile = destcopy[destfile,idx];
				newcopy[srcfile,outidx] = destfile;
				outidx++;
			}
		}

	}

	for (key in newcopy) {
		split(key, parts, SUBSEP);

		if (parts[2] == "0") {
			parts[2] = "";
		} else {
			parts[2] = parts[2] "/";
		}

		print parts[1], parts[2]  newcopy[key];
	}
}
