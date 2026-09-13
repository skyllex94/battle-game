using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class PlayerLives : MonoBehaviour {

    private Text livesText;
	// Use this for initialization
	void Awake () {
        livesText = GetComponent<Text>();
       
	}
    void Start()
    {
        InvokeRepeating("UpdateLives", 0f, 1f);
    }
	// Update is called once per frame
	void UpdateLives () {
        livesText.text = "x" + GameMaster.RemainingLives.ToString();
	}
}
