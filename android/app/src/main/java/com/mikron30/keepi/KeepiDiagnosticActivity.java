package com.mikron30.keepi;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

public class KeepiDiagnosticActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding(48, 48, 48, 48);
        root.setBackgroundColor(Color.rgb(7, 17, 29));

        TextView title = new TextView(this);
        title.setText("KEEPI VERSION 10\nNATIVE CHECK PASSED");
        title.setTextColor(Color.WHITE);
        title.setTextSize(26f);
        title.setGravity(Gravity.CENTER);
        root.addView(title);

        TextView explanation = new TextView(this);
        explanation.setText(
            "\nThis screen is pure Android.\n" +
            "Flutter, Firebase and AdMob have not started yet."
        );
        explanation.setTextColor(Color.LTGRAY);
        explanation.setTextSize(16f);
        explanation.setGravity(Gravity.CENTER);
        root.addView(explanation);

        Button start = new Button(this);
        start.setText("START FLUTTER DIAGNOSTICS");
        start.setOnClickListener(v ->
            startActivity(new Intent(this, MainActivity.class))
        );

        LinearLayout.LayoutParams buttonParams =
            new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            );
        buttonParams.setMargins(0, 48, 0, 0);
        root.addView(start, buttonParams);

        setContentView(root);
    }
}
