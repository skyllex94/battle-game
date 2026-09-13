using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

public class ConfigurationHandler : MonoBehaviour {

    public GameObject Slider1;

    public void Slide1()
    {
        SceneManager.LoadScene("MainLevel");
        //Slider1.transform.position = new Vector2(1000, 1000);
    }
}