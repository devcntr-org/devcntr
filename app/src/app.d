module app;

import dlangui;
import modules.template_installer.installer;
import modules.template_installer.project_manager;
import modules.project_recognizer.recognizer;
import modules.system_overview.tool_manager;
import modules.system_overview.widgets;
import std.stdio;
import std.path;
import std.file;
import std.conv;
import std.process : environment;
import std.algorithm : endsWith;
import std.array : empty, array;

mixin APP_ENTRY_POINT;

class DevCenterApp {
    Window window;
    TemplateInstaller installer;
    ProjectWorkspaceManager projectManager;
    ToolManager toolManager;
    ArchitectureModel currentModel;

    StringListAdapter templateAdapter;
    StringListAdapter stackAdapter;

    this() {
        // Initialize backend
        string cacheRoot = buildPath(getHomeDir(), ".dev-center", "templates");
        installer = new TemplateInstaller(cacheRoot);
        toolManager = new ToolManager();

        // Target current directory
        string projectRoot = getcwd();

        // Load recognizer rules
        string profilesDir = buildPath(projectRoot, "src", "modules", "project-recognizer", "profiles");
        ProjectRecognizer recognizer;
        if (exists(profilesDir)) {
             recognizer = ProjectRecognizer.fromProfilesDir(profilesDir);
        } else {
             recognizer = new ProjectRecognizer([RecognitionRule("Generic", "General project", "", [], [], [], [], [])]);
        }

        projectManager = new ProjectWorkspaceManager(projectRoot, recognizer);

        templateAdapter = new StringListAdapter();
        stackAdapter = new StringListAdapter();
    }

    void createUI() {
        window = Platform.instance.createWindow("Dev Center", null);

        window.mainWidget = parseML(q{
            VerticalLayout {
                layoutWidth: fill; layoutHeight: fill
                padding: 0

                // Top Bar
                HorizontalLayout {
                    layoutWidth: fill; padding: 10; background: "#121212"
                    TextWidget { text: "Dev Center"; fontSize: 18pt; fontWeight: 800; textColor: "#007AFF" }
                    Spacer { layoutWidth: fill }
                    Button { id: btnHome; text: "Home"; styleId: "BUTTON_TRANSPARENT" }
                    Button { id: btnUpdate; text: "Check for Updates" }
                }

                // Main Section with Sidebar
                HorizontalLayout {
                    layoutWidth: fill; layoutHeight: fill

                    // Left Sidebar
                    VerticalLayout {
                        id: sidebar; layoutWidth: 200; layoutHeight: fill; padding: 5
                        background: "#1A1A1A"; visibility: gone
                        Button { id: navHome; text: "Home"; layoutWidth: fill }
                        Button { id: navDashboard; text: "Tool Status"; layoutWidth: fill }
                        Button { id: navTemplates; text: "Browse Projects"; layoutWidth: fill }
                        Button { id: navProject; text: "Project Analysis"; layoutWidth: fill }
                    }

                    // Main Content
            TabHost {
                id: contentStack; layoutWidth: fill; layoutHeight: fill

                // Page 0: Home Screen
                VerticalLayout {
                    id: pageHome; layoutWidth: fill; layoutHeight: fill; padding: 40; alignment: center
                    TextWidget { text: "Welcome to Dev Center"; fontSize: 24pt; fontWeight: 800; margin: 20; alignment: center }

                            HorizontalLayout {
                                layoutWidth: fill; alignment: center; spacing: 30

                                // Choice 1: Browse Projects
                                VerticalLayout {
                                    id: choiceBrowse; layoutWidth: 300; layoutHeight: 350; padding: 20; background: "#252525"
                                    ImageWidget { drawableId: "folder_open"; layoutWidth: 128; layoutHeight: 128; alignment: center; margin: 10 }
                                    TextWidget { text: "Browse Projects"; fontSize: 16pt; fontWeight: 600; alignment: center; margin: 10 }
                                    TextWidget { text: "Explore templates, discover local projects, and manage your workspace."; fontSize: 10pt; textColor: "#AAAAAA"; alignment: center; maxLines: 3 }
                                    Spacer { layoutHeight: fill }
                                    Button { id: btnChoiceBrowse; text: "Open Browser"; layoutWidth: fill }
                                }

                                // Choice 2: Tool Status
                                VerticalLayout {
                                    id: choiceTools; layoutWidth: 300; layoutHeight: 350; padding: 20; background: "#252525"
                                    ImageWidget { drawableId: "settings"; layoutWidth: 128; layoutHeight: 128; alignment: center; margin: 10 }
                                    TextWidget { text: "Tool Status"; fontSize: 16pt; fontWeight: 600; alignment: center; margin: 10 }
                                    TextWidget { text: "overview of installed development tools, PATH variables, and available missing tools."; fontSize: 10pt; textColor: "#AAAAAA"; alignment: center; maxLines: 3 }
                                    Spacer { layoutHeight: fill }
                                    Button { id: btnChoiceTools; text: "View Dashboard"; layoutWidth: fill }
                                }
                            }
                        }

                        VerticalLayout {
                    id: pageTemplates; layoutWidth: fill; layoutHeight: fill; padding: 10
                            TextWidget { text: "Available Templates"; fontSize: 14pt; margin: 5 }
                            HorizontalLayout {
                                layoutWidth: fill; margin: 5
                                EditLine { id: searchTemplates; text: ""; layoutWidth: fill; placeholderText: "Search templates..." }
                            }
                            ListWidget { id: listTemplates; layoutWidth: fill; layoutHeight: fill }
                            HorizontalLayout {
                                Button { id: btnInstall; text: "Install Selected" }
                                Button { id: btnReview; text: "Review Files" }
                            }
                        }

                        VerticalLayout {
                    id: pageProject; layoutWidth: fill; layoutHeight: fill; padding: 10
                            TextWidget { text: "Project Analysis"; fontSize: 14pt; margin: 5 }
                            TextWidget { id: projectPathLabel; text: "Path: " }
                            ListWidget { id: listStacks; layoutWidth: fill; layoutHeight: fill }
                            HorizontalLayout {
                                Button { id: btnSaveTemplate; text: "Save as New Template" }
                                Button { id: btnSync; text: "Sync Templates" }
                            }
                        }

                        VerticalLayout {
                    id: pageDashboard; layoutWidth: fill; layoutHeight: fill; padding: 10
                            TextWidget { text: "Tool Status Overview"; fontSize: 18pt; margin: 10 }

                            TabWidget {
                                id: dashboardTabs; layoutWidth: fill; layoutHeight: fill
                                VerticalLayout { id: tabInstalled; text: "Installed"; layoutWidth: fill; layoutHeight: fill }
                                VerticalLayout { id: tabAvailable; text: "Available"; layoutWidth: fill; layoutHeight: fill }
                            }
                        }
                    }
                }
            }
        });

        // Programmatically add dashboard content
        auto tabInstalled = window.mainWidget.childById!VerticalLayout("tabInstalled");
        tabInstalled.addChild(new ToolStatusDashboard(toolManager, true));

        auto tabAvailable = window.mainWidget.childById!VerticalLayout("tabAvailable");
        tabAvailable.addChild(new ToolStatusDashboard(toolManager, false));

        auto dashboardTabs = window.mainWidget.childById!TabWidget("dashboardTabs");
        dashboardTabs.addTab(tabInstalled, "Installed Tools"d);
        dashboardTabs.addTab(tabAvailable, "Available Tools"d);

        auto listTemplates = window.mainWidget.childById!ListWidget("listTemplates");
        listTemplates.adapter = templateAdapter;

        auto listStacks = window.mainWidget.childById!ListWidget("listStacks");
        listStacks.adapter = stackAdapter;

        setupEventHandlers();
        refreshTemplates();
        refreshProject();

        window.show();
    }

    void setupEventHandlers() {
    auto contentStack = window.mainWidget.childById!TabHost("contentStack");
    auto sidebar = window.mainWidget.childById("sidebar");

        auto showPage = delegate(int index, bool showSidebar) {
        string[] pageIds = ["pageHome", "pageTemplates", "pageProject", "pageDashboard"];
        if (index >= 0 && index < pageIds.length) {
            contentStack.showChild(pageIds[index]);
        }
        sidebar.visibility = showSidebar ? Visibility.Visible : Visibility.Gone;
    };

        window.mainWidget.childById!Button("btnHome").click = delegate(Widget w) {
            showPage(0, false);
            return true;
        };
        window.mainWidget.childById!Button("navHome").click = delegate(Widget w) {
            showPage(0, false);
            return true;
        };

        window.mainWidget.childById!Button("btnChoiceBrowse").click = delegate(Widget w) {
            showPage(1, true);
            return true;
        };
        window.mainWidget.childById!Button("navTemplates").click = delegate(Widget w) {
            showPage(1, true);
            return true;
        };

        window.mainWidget.childById!Button("btnChoiceTools").click = delegate(Widget w) {
            showPage(3, true);
            return true;
        };
        window.mainWidget.childById!Button("navDashboard").click = delegate(Widget w) {
            showPage(3, true);
            return true;
        };

        window.mainWidget.childById!Button("navProject").click = delegate(Widget w) {
            showPage(2, true);
            refreshProject();
            return true;
        };

        window.mainWidget.childById!Button("btnUpdate").click = delegate(Widget w) {
            bool updated = installer.updateCache(true);
            refreshTemplates();
            window.showMessageBox(UIString.fromRaw("Status"d), UIString.fromRaw(updated ? "Cache Updated"d : "Up to Date"d));
            return true;
        };

        window.mainWidget.childById!Button("btnInstall").click = delegate(Widget w) {
            auto list = window.mainWidget.childById!ListWidget("listTemplates");
            if (list.selectedItemIndex >= 0) {
                // TODO: proper install
            }
            return true;
        };
    }

    void refreshTemplates() {
        templateAdapter.clear();
        auto templates = installer.listTemplates();
        foreach(t; templates) {
            templateAdapter.add(to!dstring(t.name));
        }
    }

    void refreshProject() {
        stackAdapter.clear();
        currentModel = projectManager.identifyStacks();
        foreach(s; currentModel.techStacks) {
            stackAdapter.add(to!dstring(s.name ~ " (" ~ s.description ~ ")"));
        }
        auto label = window.mainWidget.childById!TextWidget("projectPathLabel");
        if (label) {
            label.text = UIString.fromRaw("Path: "d ~ to!dstring(getcwd()));
        }
    }

    static string getHomeDir() {
        version(Windows) {
            string drive = environment.get("HOMEDRIVE");
            string path = environment.get("HOMEPATH");
            if (drive && path) return buildPath(drive, path);
            return environment.get("USERPROFILE");
        }
        else return environment.get("HOME");
    }
}

extern (C) int UIAppMain(string[] args) {
    auto app = new DevCenterApp();
    app.createUI();
    return Platform.instance.enterMessageLoop();
}
