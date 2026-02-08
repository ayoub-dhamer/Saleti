package com.example.saleti // Use your actual package name

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            // 1. Inflate the XML layout you created
            val views = RemoteViews(context.packageName, R.layout.prayer_widget).apply {
                
                // 2. Extract data sent from Flutter
                // The keys "next_prayer_name" and "next_prayer_time" must match Flutter
                val prayerName = widgetData.getString("next_prayer_name", "Loading...")
                val prayerTime = widgetData.getString("next_prayer_time", "--:--")

                // 3. Set the text in your XML TextViews
                setTextViewText(R.id.prayer_name_display, prayerName)
                setTextViewText(R.id.prayer_time_display, prayerTime)
            }

            // 4. Tell the manager to update the physical widget on screen
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}