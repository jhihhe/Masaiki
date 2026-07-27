package com.example.masaiki

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.core.view.WindowCompat
import com.example.masaiki.ui.MasaikiScreen
import com.example.masaiki.ui.theme.MasaikiTheme

class MainActivity : ComponentActivity() {

    private val viewModel: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContent {
            MasaikiTheme {
                Surface(color = MaterialTheme.colorScheme.background) {
                    MasaikiScreen(viewModel)
                }
            }
        }
    }
}
