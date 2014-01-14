package org.teton_landis.jake.hud;

import javafx.animation.FadeTransition;
import javafx.application.Application;
import javafx.application.Platform;
import javafx.event.ActionEvent;
import javafx.event.EventHandler;
import javafx.geometry.*;
import javafx.scene.Node;
import javafx.scene.Scene;
import javafx.scene.input.KeyCode;
import javafx.scene.input.KeyEvent;
import javafx.scene.input.MouseEvent;
import javafx.scene.layout.*;
import javafx.stage.Stage;
import javafx.stage.*;
import javafx.util.Duration;

public class HeadsUpDisplay extends Application {

    static final double fontSize = 70;
    static final double totalWidth = 1200;
    static final double sixteenNine = (9.0 / 16.0);
    static final Duration FadeTime = Duration.millis(1300);

    static public HeadsUpDisplay instance; // tricky global state !!!!

    public boolean hudIsOnScreen;
    public Stage mainStage;
    public Pane root;
    public VBox alerts;

    // transitions applied to the Root to show and hide everything
    // I'm just going for an opacity fade for now
    private FadeTransition show_transition;
    private FadeTransition hide_transition;

    private static class Delta { double x, y; }

    /**
     * what the fuck am i doing java?
     * not typing "new String[] { ... }" every time i want an array, that's what
     * #drunkCoding
     * @param derp some strings in a raw array
     * @return derp
     */
    static private String[] str(String... derp) { return derp; }

    /**
     * Make a whole stage draggable by a node. Useful for moving an undecorated
     * window around.
     * https://stackoverflow.com/questions/11780115/moving-an-undecorated-stage-in-javafx-2
     * @param stage to be made draggable
     * @param node drag handle
     */
    static private void dragStageByNode(final Stage stage, Node node) {
        final Delta dragDelta = new Delta();
        node.setOnMousePressed(new EventHandler<MouseEvent>() {
            @Override
            public void handle(MouseEvent mouseEvent) {
                // record a delta distance for the drag and drop operation.
                dragDelta.x = stage.getX() - mouseEvent.getScreenX();
                dragDelta.y = stage.getY() - mouseEvent.getScreenY();
            }
        });
        node.setOnMouseDragged(new EventHandler<MouseEvent>() {
            @Override public void handle(MouseEvent mouseEvent) {
                stage.setX(mouseEvent.getScreenX() + dragDelta.x);
                stage.setY(mouseEvent.getScreenY() + dragDelta.y);
            }
        });
    }

    /**
     * Show the heads-up display (fade in)
     */
    public void showHud() {
        // do nothing if already open
        if (hudIsOnScreen) return;

        hudIsOnScreen = true;
        hide_transition.stop();

        // getOpacity so we look good interrupting a Hide.
        // note that the opacity must be set to 0.0 in the constructor
        show_transition.setFromValue(root.getOpacity());

        mainStage.show();
        mainStage.toFront();
        show_transition.play();
    }

    /**
     * Hide the heads-up display (fade out)
     */
    public void hideHud() {
        // do nothing if already hidden
        if (! hudIsOnScreen) return;

        hudIsOnScreen = false;
        show_transition.stop();

        hide_transition.setFromValue(root.getOpacity());
        hide_transition.play();
        // mainStage.hide(); // handled by an event handler configured in start()

    }

    /**
     * remove all text from the HUD
     */
    public void clearAlerts() {
        alerts.getChildren().removeAll(alerts.getChildren());
    }

    /**
     * Create a new StyledTextFlow layout with its own style classes applied,
     * and fill that layout with Text nodes as seen in StyledTextFlow#addTextWithStyles
     *
     * meat and potatoes of the ruby interface. hope this works :|
     * @param style_classes classes to be applied to the parent text node
     * @param content_and_styles Each String[] like
     *                           String[]{"some text content", "class1", ..., "classN"}
     */
    public StyledTextFlow pushAlert(String[] style_classes, String[]... content_and_styles) {
        StyledTextFlow flow = new StyledTextFlow(content_and_styles);
        flow.getStyleClass().addAll(style_classes);

        alerts.getChildren().add(flow);

        return flow;
    }

    /**
     * creates a few example alerts for the hypothetical user query,
     * "Ok tv. Play Breaking Bad season two episode four please"
     */
    public void pushExamples() {
        pushAlert(str("small", "action"), // classes
                str("♦ Intent:"),         // content
                str("query episode → play" , "action")
        );

        // main body contents -- what the user put into the webui system
        pushAlert(str("large"),
                str("Ok tv. Play"),
                str("Breaking Bad", "entity"),
                str("season"),
                str("two", "entity"),
                str("episode"),
                str("four", "entity"),
                str("please")
        );

        // bottom -- result
        pushAlert(str("small", "result"),
                str("found"),
                str("Breaking Bad - S02E04 - Thirty-Eight Snub", "entity")
        );

        pushAlert(str("small"), str("playing with VLC."));

    }


    @Override
    public void start(final Stage primaryStage) throws Exception{

        // initial setup
        mainStage = primaryStage;
        final HeadsUpDisplay app = this; // for callbacks
        instance = app;

        // create root
        root = new StackPane();
        root.setOpacity(0.0); // required for nice fade-in
        root.setId("root");
        // drag window from anywhere
        dragStageByNode(primaryStage, root);


        // create "alerts" vbox and add it to the root
        alerts = new VBox();
        alerts.setId("alerts");
        root.getChildren().add(alerts);
        StackPane.setMargin(alerts, new Insets(fontSize / 2, fontSize, fontSize / 2, fontSize));
        StackPane.setAlignment(alerts, Pos.TOP_CENTER);

        // set up transitions
        show_transition = new FadeTransition(FadeTime, root);
        show_transition.setFromValue(0.0);
        show_transition.setToValue(1.0);

        hide_transition = new FadeTransition(FadeTime, root);
        hide_transition.setFromValue(1.0);
        hide_transition.setToValue(0.0);

        hide_transition.setOnFinished(new EventHandler<ActionEvent>() {
            @Override
            public void handle(ActionEvent actionEvent) {
                app.mainStage.hide();
            }
        });

        // scene setup
        Scene scene = new Scene(root, totalWidth, totalWidth*sixteenNine);
        scene.getStylesheets().addAll(this.getClass().getResource("/style.css").toExternalForm());
        scene.setFill(null); // transparent

        // hide HUD on ESCAPE
        scene.setOnKeyReleased(new EventHandler<KeyEvent>() {
            @Override
            public void handle(KeyEvent keyEvent) {
                if (keyEvent.getCode() == KeyCode.ESCAPE) {
                    app.hideHud();
                }
            }
        });

        // stage setup
        primaryStage.setTitle("HUD");
        primaryStage.initStyle(StageStyle.TRANSPARENT);
        primaryStage.setScene(scene);
    }

    public static void main(String[] args) {
        Platform.setImplicitExit(false);
        launch(args);
    }
}
