#
# Armitage Collaboration Feature... make no mistake, I'm extremely excited about this.
#

import msf.*;
import armitage.*;
import console.*;

sub createEventLogTab {
	this('$console $client');

	if ($client is $null && $console is $null) {
		$client = [new ConsoleClient: $null, $mclient, "armitage.poll", "armitage.push", $null, "", $null];
        	$console = [new ActivityConsole: $preferences];
		logCheck($console, "all", "events");
	        [$client setWindow: $console];
		[$client setEcho: $null];
		[$console updatePrompt: "> "];
	}
	else {
		[$console updateProperties: $preferences];
	}

        [$frame addTab: "Event Log", $console, $null];
}

sub c_client {
	# run this thing in its own thread to avoid really stupid deadlock situations
	return wait(fork({
		local('$handle $client');
		$handle = connect($host, $port, 5000);
		$client = newInstance(^RpcConnection, lambda({
			writeObject($handle, @_);
			return readObject($handle);
		}, \$handle));
		return [new RpcAsync: $client];
	}, $host => $1, $port => $2));
}

sub userFingerprint {
	return unpack("H*", digest(values(systemProperties(), @("os.name", "user.home", "os.version")), "MD5"))[0];
}

sub setup_collaboration {
	local('$nick %r $mclient');
	
	$nick = ask("What is your nickname?");

	while (["$nick" trim] eq "") {
		$nick = ask("You can't use a blank nickname. What do you want?");
	}

	$mclient = c_client($3, $4);
	%r = call($mclient, "armitage.validate", $1, $2, $nick, "armitage", 120326);
	if (%r["error"] eq "1") {
		showErrorAndQuit(%r["message"]);
	}

	%r = call($client, "armitage.validate", $1, $2, $null, "armitage", 120326);
	return $mclient;
}

sub uploadFile {
	local('$handle %r $data');

	$handle = openf($1);
	$data = readb($handle, -1);
	closef($handle);

	%r = call($mclient, "armitage.upload", getFileName($1), $data);
	return %r['file'];
}

sub uploadBigFile {
	local('$handle %r $data $file $progress $total $sofar $time $start');

	$total = lof($1);
	$progress = [new javax.swing.ProgressMonitor: $null, "Upload " . getFileName($1), "Starting upload", 0, lof($1)];
	$start = ticks();
	$handle = openf($1);
	$data = readb($handle, 1024 * 256);
	%r = call($mclient, "armitage.upload", getFileName($1), $data);
	$sofar += strlen($data);

	while $data (readb($handle, 1024 * 256)) {
		$time = (ticks() - $start) / 1000.0;
		[$progress setProgress: $sofar];
		[$progress setNote: "Speed: " . round($sofar / $time) . " bytes/second"];
		call($mclient, "armitage.append", getFileName($1), $data);
		$sofar += strlen($data);
	}
	[$progress close];
	return %r['file'];
}

sub downloadFile {
	local('$file $handle %r $2');
	%r = call($mclient, "armitage.download", $1);
	$file = iff($2, $2, getFileName($1));	
	$handle = openf("> $+ $file");
	writeb($handle, %r['data']);
	closef($handle);
	return $file;
}

sub getFileContent {
	local('$file $handle %r');
	if ($mclient !is $client) {
		%r = call($mclient, "armitage.download_nodelete", $1);
		return %r['data'];
	}
	else {
		$handle = openf($1);
		$file = readb($handle, -1);
		closef($handle);
		return $file;
	}
}

# returns the folder where files should be downloaded to!
sub downloadDirectory {
	if ($client is $mclient) {
		local('@dirs $start $dir');
		$start = dataDirectory();
		push(@dirs, "downloads");
		addAll(@dirs, @_);
	
		foreach $dir (@dirs) {
			if (isWindows()) {
				$dir = strrep($dir, "/", "\\", ":", "");
			}
			$start = getFileProper($start, $dir);
		}
		return $start;
	}
	else {
		return "downloads/" . join("/", @_);
	}
}
