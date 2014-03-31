/*
    Copyright (C) 2012 Johan Mattsson

    This library is free software; you can redistribute it and/or modify 
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but 
    WITHOUT ANY WARRANTY; without even the implied warranty of 
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Lesser General Public License for more details.
*/
using BirdFont;
public const string GETTEXT_PACKAGE = "birdfont"; 

namespace BirdFont {
	
static void print_export_help (string[] arg) {
	stdout.printf (t_("Usage:"));
	stdout.printf (arg[0]);
	stdout.printf (" [OPTION ...] FILE\n");
	stdout.printf ("-h, --help                      " + t_("print this message\n"));
	stdout.printf ("-o, --output [DIRECTORY]        " + t_("write files to this directory\n"));
	stdout.printf ("-s, --svg                       " + t_("write svg file\n"));
	stdout.printf ("-t, --ttf                       " + t_("write ttf and eot files\n"));
	stdout.printf ("\n");
}

public static int run_export (string[] arg) {
	string output_directory = ".";
	string file_name = "";
	bool specific_formats = false;	
	bool write_ttf = false;
	bool write_svg = false;	
	File directory;
	
	stdout.printf ("birdfont-export version %s\n", VERSION);
	stdout.printf ("built on %s\n", BUILD_TIMESTAMP);

	if (arg.length < 2) {
		print_export_help (arg);
		return -1;
	}
	
	// FIXME: create a option for this and structure the log messages
	// init_logfile ();
	
	for (int i = 1; i < arg.length; i++) {

		if (arg[i] == "-f" || arg[i] == "--fatal-warnings") {
			BirdFont.fatal_wanings = true;
			return 0;
		}

		if (arg[i] == "-h" || arg[i] == "--help") {
			print_export_help (arg);
			return 0;
		}
		
		if ((arg[i] == "-o" || arg[i] == "--output") && i + 1 < arg.length) {
			output_directory = arg[i + 1];
			i++;
			continue;
		}

		if (arg[i] == "-s" || arg[i] == "--svg") {
			write_svg = true;
			specific_formats = true;
			continue;
		}
		
		if (arg[i] == "-t" || arg[i] == "--ttf") {
			write_ttf = true;
			specific_formats = true;
			continue;
		}
		
		if (arg[i].has_prefix ("-")) {
			print_export_help (arg);
			return 1;
		}
		
		if (!arg[i].has_prefix ("-")) {
			file_name = arg[i];
						
			if (i != arg.length - 1) {
				print_export_help (arg);
				return 1;
			}
			
			break;
		}
	}

	if (BirdFont.fatal_wanings) {
		LogLevelFlags levels = LogLevelFlags.LEVEL_ERROR | LogLevelFlags.LEVEL_CRITICAL | LogLevelFlags.LEVEL_WARNING;
		Log.set_handler (null, levels, BirdFont.fatal_warning);		
	}
	
	Preferences.load ();
			
	BirdFont.args = new Argument ("");
	BirdFont.current_font = new Font ();
	BirdFont.current_glyph = new Glyph ("");
	
	if (!BirdFont.get_current_font ().load (file_name, false)) {
		warning (@"Failed to load font $file_name.\n");
		
		if (!file_name.has_suffix (".bf")) {
			warning (@"Is it a .bf file?\n");
		}
		
		return 1;
	}

	directory = File.new_for_path (output_directory);
	
	if (!directory.query_exists ()) {
		stderr.printf (t_("Can't find output directory") + @"$((!)directory.get_path ())\n");
		return 1;
	}

	if (!specific_formats || write_svg) {
		print (@"Writing $(BirdFont.current_font.get_name ()).svg to $output_directory\n");
		ExportTool.export_svg_font_path (File.new_for_path (output_directory));
	}

	if (!specific_formats || write_ttf) {
		print (@"Writing $(BirdFont.current_font.get_name ()).ttf to $output_directory\n");
		ExportTool.export_ttf_font_path (File.new_for_path (output_directory), false);
	}
	
	Toolbox.redraw_tool_box ();
	return 0;
}

public static string wine_to_unix_path (string exec_path) {
	bool drive_c, drive_z;
	int i;
	string p, q;

	p = exec_path;
	p = p.replace ("\\", "/");
	
	drive_c = exec_path.index_of ("C:") == 0;
	drive_z = exec_path.index_of ("Z:") == 0;
	
	i = p.index_of (":");
	
	if (i != -1) {
		p = p.substring (i + 2);
	}

	if (drive_c) {
		q = @"/home/$(Environment.get_user_name ())/.wine/drive_c/" + p;
		
		if (File.new_for_path (q).query_exists ()) {
			return q;
		} else {
			return p;
		}
	}
	
	if (drive_z) {
		return ("/" + p).dup ();
	}

	return exec_path.dup ();
}

public bool is_null (void* n) {
	return n == null;
}

public bool has_flag (uint32 flag, uint32 mask) {
	return (flag & mask) > 0;
}

public class BirdFont {
	public static Argument args;
	public static bool experimental = false;
	public static bool show_coordinates = false;
	public static bool fatal_wanings = false;
	public static bool win32 = false;
	public static bool mac = false;
	public static bool android = false;
	public static string exec_path = "";
	public static string bundle_path = "";

	public static bool logging = false;
	public static DataOutputStream? logstream = null;

	public static Font current_font;
	public static Glyph current_glyph;
	
	public BirdFont () {	
	}
	
	/**
	 * @param arg command line arguments
	 * @param program path
	 */
	public void init (string[] arg, string? program_path) {
		int err_arg;
		int i;
		File font_file;
		string exec_path;

		args = new Argument.command_line (arg);

#if ANDROID
		BirdFont.logging = true;
		
		__android_log_print (ANDROID_LOG_WARN, "BirdFont", @"libbirdfont version $VERSION");
		LogLevelFlags log_levels = LogLevelFlags.LEVEL_ERROR | LogLevelFlags.LEVEL_CRITICAL | LogLevelFlags.LEVEL_WARNING;
		Log.set_handler (null, log_levels, android_warning);
		
		android = true;
#else
		stdout.printf ("birdfont version %s\n", VERSION);
		stdout.printf ("built on %s\n", BUILD_TIMESTAMP);
		
		android = args.has_argument ("--android");
		BirdFont.logging = args.has_argument ("--log");
#endif

		if (BirdFont.logging) {
			init_logfile ();
		}
		
		if (!args.has_argument ("--no-translation")) {
			init_gettext ();
		}

		if (args.has_argument ("--help")) {
			args.print_help ();
			Process.exit (0);
		}

		err_arg = args.validate ();
		if (err_arg != 0) {
			stdout.printf (@"Unknown parameter $(arg [err_arg])\n\n");
			args.print_help ();
			Process.exit (0);
		}

		Preferences.load ();
		
		current_font = new Font ();
		current_font.set_name ("");
		current_font.initialised = false;
		current_glyph = new Glyph ("");
		
		experimental = args.has_argument ("--test");
		show_coordinates = args.has_argument ("--show-coordinates") || experimental;
		fatal_wanings = args.has_argument ("--fatal-warning");
		win32 = (arg[0].index_of (".exe") > -1) || arg[0] == "wine";

#if MAC
		mac = true;
#else
		mac = args.has_argument ("--mac");
#endif
	
		if (program_path == null) {
			exec_path = "";

			if (win32) {
				// wine hack to get "." folder in win32 environment
				i = arg[0].last_index_of ("\\");
				
				if (i != -1) {	
					exec_path = arg[0];
					exec_path = exec_path.substring (0, i);
					exec_path = wine_to_unix_path (exec_path);			
				}
			} else {
				exec_path = "./";
			}
		} else {
			exec_path = (!) program_path;
		}
		
		if (args.get_file () != "") {
			font_file = File.new_for_path (args.get_file ());
			
			if (!font_file.query_exists ()) {
				stderr.printf (@"File $(args.get_file ()) not found.");
				Process.exit (-1);
			}
		}

		if (fatal_wanings) {
			LogLevelFlags levels = LogLevelFlags.LEVEL_ERROR | LogLevelFlags.LEVEL_CRITICAL | LogLevelFlags.LEVEL_WARNING;
			Log.set_handler (null, levels, fatal_warning);
		}
		
		Preferences.set_last_file (get_current_font ().get_path ());
		
		DefaultCharacterSet.create_default_character_sets ();
		DefaultCharacterSet.get_characters_for_prefered_language ();

		HeadTable.init ();
		
		printd ("Done");
	}

	public static void set_bundle_path (string path) {
		bundle_path = path;	
	}

	static void init_gettext () {
		// FIXME: android this should be OK now
#if !ANDROID
		string locale_directory = SearchPaths.get_locale_directory ();
		Intl.setlocale (LocaleCategory.MESSAGES, "");
		Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "utf-8");
		Intl.bindtextdomain (GETTEXT_PACKAGE, locale_directory);
#endif
	}
	
	public static Font get_current_font () {
		return current_font;
	}

	internal static void fatal_warning (string? log_domain, LogLevelFlags log_levels, string message) {		
		bool fatal = true;
		
		if (log_domain != null) {
			stderr.printf ("%s: \n", (!) log_domain);
		}
		
		stderr.printf ("\n%s\n\n", message);
		assert (!fatal);
	}

#if ANDROID
	internal static void android_warning (string? log_domain, LogLevelFlags log_levels, string message) {
		__android_log_print (ANDROID_LOG_WARN, "BirdFont", message);
	}
#endif
	
	internal static Font new_font () {
		current_font = new Font ();
		return current_font;
	}

	public static File get_preview_directory () {
		File settings = get_settings_directory ();
		File backup = settings.get_child ("preview");
		
		if (!backup.query_exists ()) {
			DirUtils.create ((!) backup.get_path (), 0xFFFFFF);
		}
			
		return backup;
	}

	internal static File get_thumbnail_directory () {
		File thumbnails = get_settings_directory ().get_child ("thumbnails");
		
		if (!thumbnails.query_exists ()) {
			DirUtils.create ((!) thumbnails.get_path (), 0xFFFFFF);
		}
		
		return thumbnails;
	}
		
	internal static File get_settings_directory () {
		string home_path;
		File home;
		File settings;

#if ANDROID
		home_path = "/data/data/org.birdfont.sefyr/files";
		home = File.new_for_path (home_path);

		if (!home.query_exists ()) {
			printd ("Create settings directory.");
			DirUtils.create ((!) home.get_path (), 0xFFFFFF);
		}
#else
		home_path = Environment.get_home_dir ();
	
		if (is_null (home_path)) {
			warning ("No home directory set.");
			home_path = ".";
		}
		
		home = File.new_for_path (home_path);
#endif
		settings = home.get_child (".birdfont");
				
		if (!settings.query_exists ()) {
			DirUtils.create ((!) settings.get_path (), 0xFFFFFF);
		}
			
		return settings;
	}

	internal static File get_backup_directory () {
		File settings = get_settings_directory ();
		File backup = settings.get_child ("backup");
		
		if (!backup.query_exists ()) {
			DirUtils.create ((!) backup.get_path (), 0xFFFFFF);
		}
			
		return backup;
	}

	public static bool has_argument (string param) {
		if (is_null (args)) {
			warning ("args is null");
			return false;
		}
		
		return args.has_argument (param);
	}
	
	internal static string? get_argument (string param) {
		return args.get_argument (param);
	}	
}

void init_logfile () {
	DateTime t;
	File settings;
	string s;
	File log;
	
	try {
		t = new DateTime.now_local ();
		settings = BirdFont.get_settings_directory ();
		s = t.to_string ().replace (":", "_");
		log = settings.get_child (@"birdfont_$s.log");
		
		BirdFont.logstream = new DataOutputStream (log.create (FileCreateFlags.REPLACE_DESTINATION));
		((!)BirdFont.logstream).put_string ((!) log.get_path ());
		((!)BirdFont.logstream).put_string ("\n");
		
		warning ("Logging to " + (!) log.get_path ());
	} catch (GLib.Error e) {
		warning (e.message);
		warning ((!) log.get_path ());
	}

	LogLevelFlags levels = LogLevelFlags.LEVEL_ERROR | LogLevelFlags.LEVEL_CRITICAL | LogLevelFlags.LEVEL_WARNING | LogLevelFlags.LEVEL_DEBUG;
	Log.set_handler (null, levels, log_warning);		
		
	BirdFont.logging = true;
}

internal static void log_warning (string? log_domain, LogLevelFlags log_levels, string message) {
	if (log_domain != null) {
		printd ((!) log_domain);
	}
	
	printd ("\n");
	printd (message);
	printd ("\n");
	printd ("\n");
}

/** Write debug output to logfile. */
void printd (string s) {
#if ANDROID
	__android_log_print (ANDROID_LOG_WARN, "BirdFont", s);
#else
	if (unlikely (BirdFont.logging)) {
		try {
			if (BirdFont.logstream != null) {
				((!)BirdFont.logstream).put_string (s);
			} else {
				warning ("No logstream.");
			}
		} catch (GLib.Error e) {
			warning (e.message);
		}
	}
#endif
}

/** Translate string */
public string t_ (string t) {
	return _(t);
}

}
