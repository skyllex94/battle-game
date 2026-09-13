using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Parallaxing : MonoBehaviour {

    public Transform[] backgrounds;  // Array of parallaxing
    private float[] parallaxScales; // proportion of cameras movements to move the backgrounds
    public float smoothing; // How smooth the parallax will be

    private Transform cam;   // reference to the main cameras
    private Vector3 previousCamPos;     // the position of the cametra in the previous frame

    void Awake()    // called before Start()
    {
        // set camera reference
        cam = Camera.main.transform;
    }
	
	void Start () {
        previousCamPos = cam.position;
        // assigning corresponding parallaxScales
        parallaxScales = new float[backgrounds.Length];

        for (int i = 0; i < backgrounds.Length; i++)
        {
            parallaxScales[i] = backgrounds[i].position.z * -1;
        }
	}
	
	void Update () {
        for (int i = 0; i < backgrounds.Length; i++)
        {
            // the parallax in the opposite to the camera movement
            float parallax = (previousCamPos.x - cam.position.x) * parallaxScales[i];

            // set  a terget x posistion which is the current position plus parallax
            float backgroundTargetPosX = backgrounds[i].position.x + parallax;

            // create a target position which is the background current position with it's tarteg X
            Vector3 backgroundTargetPos = new Vector3(backgroundTargetPosX, backgrounds[i].position.y, backgrounds[i].position.z);

            // fade between current and target position
            backgrounds[i].position = Vector3.Lerp(backgrounds[i].position, backgroundTargetPos, smoothing * Time.deltaTime);
        }
        // set the previousCamPox to the camare;s postion at the end of the frame
        previousCamPos = cam.position;
	}
}
