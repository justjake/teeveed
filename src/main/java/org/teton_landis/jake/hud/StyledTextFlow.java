package org.teton_landis.jake.hud;

import javafx.scene.layout.FlowPane;
import javafx.scene.text.Text;

import java.util.Arrays;

/**
 * JavaFX versions less than 8.0 (with Java 8) don't have a way to put
 * styles on substrings of a Text object. This solves that problem
 * by providing one simple constructor to create a flow pane, Text objects,
 * and put the right string contents into the texts with the right style.
 *
 * we do this by providing a Text object for each word in the FlowPane
 * (so things wrap correctly) and then an adequate hgap and vgap for the
 * font-size and line-spacing, respectively.
 *
 * This option is pretty expensive in terms of layout time. Once I switched
 * to this from
 */
public class StyledTextFlow extends FlowPane {

    // maybe add a Texts property here so we can swap em out or change styling?

    /**
     * Shortcut initializer that immediately calls AddTextWithStyles on the parameters
     * @param content_and_styles see addTextWithStyles
     */
    public StyledTextFlow(String[]... content_and_styles) {
        super();
        addTextWithStyles(content_and_styles);
    }

    /**
     * Pass any number of string arrays. The first string in the array is
     * the text to create, and the remaining items in the array are StyleClasses
     * for that text.
     *
     * This method is a bit... stringly-typed... but what can you really do?
     *
     * @param content_and_styles String[]{text, style1, style2, ..., styleN}
     */
    public void addTextWithStyles(String[]... content_and_styles) {
        for (String[] params : content_and_styles) {
            String[] classes;
            if (params.length > 1) {
                classes = Arrays.copyOfRange(params, 1, params.length);
            } else {
                classes = new String[0];
            }
            this.getChildren().addAll(textFromParamArray(params[0], classes));
        }
    }

    /**
     * Assists the constructor.
     * @param contents Text content
     * @param styles StyleClasses for the new Text objects
     */
    private Text[] textFromParamArray(String contents, String... styles) {
        String[] words = contents.split("\\s");
        Text[] texts = new Text[words.length];

        for (int i=0; i<words.length; i++) {
            texts[i] = new Text(words[i]);
            texts[i].getStyleClass().addAll(styles);
        }

        return texts;
    }

}
